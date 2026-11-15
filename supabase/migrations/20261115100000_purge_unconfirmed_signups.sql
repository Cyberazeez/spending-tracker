-- Owner decision 2026-11-15: an account whose email was never confirmed is deleted automatically after 7 days.
-- Supabase Auth never removes unconfirmed sign-ups itself, so without this they stay forever with their email
-- address and the starter rows the sign-up trigger seeded (categories, settings, merchant rules).
--
-- Deleted only when ALL of these hold, so a real account can never match:
--   * email and phone both unconfirmed, never signed in, not anonymous, created more than 7 days ago
--     (a row with no created_at never matches);
--   * no sign-in method other than email (an Apple account always has an 'apple' identity, so it is never touched);
--   * no transactions and no saved bank messages (an unconfirmed account cannot sign in to make any, so this is a
--     second guard, not an expected case);
--   * not waiting in the 30-day account deletion grace period (purge_deleted_accounts handles those).
-- Deleting the auth.users row removes the account's own rows through the existing "on delete cascade" keys.
-- Each account is deleted in its own block, so one failure does not stop the others (same as purge_deleted_accounts).
create or replace function public.purge_unconfirmed_signups()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n int := 0;
begin
  for r in
    select u.id from auth.users u
    where u.email_confirmed_at is null
      and u.phone_confirmed_at is null
      and u.last_sign_in_at is null
      and not u.is_anonymous
      and u.created_at < now() - interval '7 days'
      and not exists (select 1 from auth.identities i where i.user_id = u.id and i.provider <> 'email')
      and not exists (select 1 from public.transactions t where t.user_id = u.id)
      and not exists (select 1 from public.raw_messages m where m.user_id = u.id)
      and not exists (select 1 from public.account_deletions d where d.user_id = u.id)
  loop
    begin
      delete from auth.users where id = r.id;
      n := n + 1;
    exception when others then
      raise warning 'purge_unconfirmed_signups: could not delete %: %', r.id, sqlerrm;
    end;
  end loop;
  return n;
end;
$$;
revoke execute on function public.purge_unconfirmed_signups() from public, anon, authenticated;
grant execute on function public.purge_unconfirmed_signups() to service_role;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('purge-unconfirmed-signups', '37 1 * * *', 'select public.purge_unconfirmed_signups()');
  end if;
end;
$$;

-- Account deletion purge, hardened (ship review 2026-11-04):
--  * an account that signed in after it asked to be deleted is never purged (the app also cancels the request at
--    sign-in; this covers the case where that call failed), and its stale request is cleared;
--  * one account that cannot be deleted no longer stops the others (each is deleted in its own block).
create or replace function public.purge_deleted_accounts()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n int := 0;
begin
  delete from public.account_deletions d
  using auth.users u
  where u.id = d.user_id and u.last_sign_in_at is not null and u.last_sign_in_at > d.requested_at;

  for r in
    select d.user_id from public.account_deletions d
    where d.requested_at < now() - interval '30 days'
  loop
    begin
      delete from auth.users where id = r.user_id;
      n := n + 1;
    exception when others then
      raise warning 'purge_deleted_accounts: could not delete %: %', r.user_id, sqlerrm;
    end;
  end loop;
  return n;
end;
$$;
revoke execute on function public.purge_deleted_accounts() from public, anon, authenticated;
grant execute on function public.purge_deleted_accounts() to service_role;

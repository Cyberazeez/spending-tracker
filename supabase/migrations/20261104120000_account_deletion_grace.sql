-- Account deletion with a 30-day grace period. Asking to delete only marks the account; signing in again within
-- 30 days cancels it, and a daily job removes accounts still marked after 30 days (every table follows by cascade).

create table public.account_deletions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  requested_at timestamptz not null default now()
);
alter table public.account_deletions enable row level security;
create policy account_deletions_select on public.account_deletions for select to authenticated
  using (user_id = auth.uid());
revoke all on public.account_deletions from anon, authenticated;
grant select on public.account_deletions to authenticated;

-- Called by the delete-account function (after the password check): mark the account, stop SMS capture and
-- the widget (their tokens are revoked) and end every signed-in session.
create or replace function public.request_account_deletion(p_user uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_at timestamptz;
begin
  insert into public.account_deletions (user_id) values (p_user)
  on conflict (user_id) do update set user_id = excluded.user_id
  returning requested_at into v_at;
  update public.ingest_tokens set revoked_at = now() where user_id = p_user and revoked_at is null;
  delete from auth.sessions where user_id = p_user;
  return v_at;
end;
$$;
revoke execute on function public.request_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.request_account_deletion(uuid) to service_role;

-- Called by the app right after a successful sign-in: true when a pending deletion was just cancelled.
create or replace function public.reactivate_my_account()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from public.account_deletions where user_id = auth.uid();
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke execute on function public.reactivate_my_account() from public, anon;
grant execute on function public.reactivate_my_account() to authenticated;

-- The daily job: delete accounts whose grace period is over.
create or replace function public.purge_deleted_accounts()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  delete from auth.users
  where id in (select user_id from public.account_deletions where requested_at < now() - interval '30 days');
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function public.purge_deleted_accounts() from public, anon, authenticated;
grant execute on function public.purge_deleted_accounts() to service_role;

-- Schedule it where pg_cron exists (the Supabase project); a plain Postgres (local tests) skips this.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('purge-deleted-accounts', '17 1 * * *', 'select public.purge_deleted_accounts()');
  end if;
end;
$$;

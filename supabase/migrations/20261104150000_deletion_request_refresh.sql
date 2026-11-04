-- A second deletion request (a retry after a lost answer, or pressing delete twice) restarts the clock: the password
-- re-check in delete-account counts as a sign-in, and with the old requested_at the purge job would have taken it for
-- a sign-in AFTER the request and kept the account forever.
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
  on conflict (user_id) do update set requested_at = now()
  returning requested_at into v_at;
  update public.ingest_tokens set revoked_at = now() where user_id = p_user and revoked_at is null;
  delete from auth.sessions where user_id = p_user;
  return v_at;
end;
$$;
revoke execute on function public.request_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.request_account_deletion(uuid) to service_role;

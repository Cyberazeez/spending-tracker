-- reactivate_my_account cancels a pending deletion only for a token issued after the deletion was requested.
-- Before this the only guard was in the app (last sign-in under 15 minutes); a stale JWT from another device, valid
-- for up to an hour after the request, could call the function directly. Requesting a deletion deletes every session,
-- so a token issued after requested_at can only come from a new sign-in.
create or replace function public.reactivate_my_account()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  v_iat timestamptz;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  v_iat := to_timestamp(nullif(auth.jwt() ->> 'iat', '')::bigint);
  if v_iat is null then return false; end if;
  delete from public.account_deletions
   where user_id = auth.uid() and requested_at < v_iat;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke execute on function public.reactivate_my_account() from public, anon;
grant execute on function public.reactivate_my_account() to authenticated;

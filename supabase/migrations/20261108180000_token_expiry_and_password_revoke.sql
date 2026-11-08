-- Device tokens no longer live forever.
-- 1. Idle expiry: a token (any kind) not used for 90 days is revoked by a daily job. The phone notices that it has no
--    active token on the server and asks for a new one (see ensureCaptureReady / ensureWidgetReady in the app).
-- 2. A password change (or reset) revokes the app and widget tokens at once, on the server, so a stolen phone's
--    tokens stop working even when the phone that changed the password is offline. The shortcut token is kept: it is
--    pasted into a hand-built shortcut and rotated with the script.

create or replace function public.expire_idle_ingest_tokens()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  update public.ingest_tokens set revoked_at = now()
   where revoked_at is null and coalesce(last_used_at, created_at) < now() - interval '90 days';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function public.expire_idle_ingest_tokens() from public, anon, authenticated;
grant execute on function public.expire_idle_ingest_tokens() to service_role;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-idle-ingest-tokens', '27 1 * * *', 'select public.expire_idle_ingest_tokens()');
  end if;
end;
$$;

create or replace function public.revoke_device_tokens_on_password_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.encrypted_password is distinct from old.encrypted_password then
    update public.ingest_tokens set revoked_at = now()
     where user_id = new.id and kind in ('app', 'widget') and revoked_at is null;
  end if;
  return new;
end;
$$;
revoke execute on function public.revoke_device_tokens_on_password_change() from public, anon, authenticated;

create trigger revoke_device_tokens_on_password_change
  after update of encrypted_password on auth.users
  for each row execute function public.revoke_device_tokens_on_password_change();

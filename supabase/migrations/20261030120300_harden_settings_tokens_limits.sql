-- Review fixes (ship-review round 1).

-- 1. settings: the owner may read and edit preferences, but not the server-enforced AI cap,
--    and cannot create or delete the row (it is seeded by seed_defaults).
-- The existing owner policy stays; the privileges below are what limit it (grants are checked before RLS).
revoke insert, update, delete on public.settings from authenticated;
grant update (ai_enabled, locale, week_start, timezone, base_salary_halalas, salary_account_last4)
  on public.settings to authenticated;

-- 2. Token rotation is one atomic step, and at most one token can be active.
create unique index ingest_tokens_one_active on public.ingest_tokens (user_id) where revoked_at is null;

create or replace function public.rotate_ingest_token(p_user uuid, p_hash text, p_label text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 0));
  update public.ingest_tokens set revoked_at = now() where user_id = p_user and revoked_at is null;
  insert into public.ingest_tokens (user_id, label, token_hash) values (p_user, p_label, p_hash);
end;
$$;
revoke execute on function public.rotate_ingest_token(uuid, text, text) from public, anon, authenticated;
grant execute on function public.rotate_ingest_token(uuid, text, text) to service_role;

-- 3. Rate limiter: per-minute and per-day windows, and old windows are purged.
--    Use distinct bucket names per window ('ingest_min', 'ingest_day').
--    The old two-argument bump_rate_limit(uuid, text) is left in place until the new ingest is
--    deployed, and is dropped by a later migration.
create function public.bump_rate_limit(p_user uuid, p_bucket text, p_window text)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start timestamptz;
  v_count int;
begin
  if p_window not in ('minute', 'day') then
    raise exception 'bad window';
  end if;
  v_start := date_trunc(p_window, now());
  insert into public.rate_limits as r (user_id, bucket, window_start, count)
  values (p_user, p_bucket, v_start, 1)
  on conflict (user_id, bucket, window_start) do update set count = r.count + 1
  returning r.count into v_count;
  if v_count = 1 then
    delete from public.rate_limits where window_start < now() - interval '2 days';
  end if;
  return v_count;
end;
$$;
revoke execute on function public.bump_rate_limit(uuid, text, text) from public, anon, authenticated;
grant execute on function public.bump_rate_limit(uuid, text, text) to service_role;

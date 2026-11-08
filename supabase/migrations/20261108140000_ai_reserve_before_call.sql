-- AI cost is reserved before the model call (atomic), then settled with the real cost.
-- Before this, the cap was check-then-record: parallel calls could all pass the check and overshoot the cap.
-- A reservation is an ai_usage row carrying the worst-case cost; settling replaces it with the real tokens and cost,
-- releasing deletes it when the call failed before any billing. A crash between reserve and settle keeps the
-- (tiny) worst-case estimate, which errs on the safe side.

create or replace function public.ai_reserve(
  p_user uuid, p_purpose text, p_estimate bigint, p_user_cap bigint, p_global_cap bigint, p_since timestamptz
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mine bigint;
  v_total bigint;
  v_id uuid;
begin
  if p_estimate is null or p_estimate < 1 then raise exception 'bad_estimate'; end if;
  -- One lock for all AI budgeting: the volume is tiny and a single total keeps the global ceiling exact.
  perform pg_advisory_xact_lock(hashtext('ai_budget'));
  select coalesce(sum(cost_halalas) filter (where user_id = p_user), 0)::bigint,
         coalesce(sum(cost_halalas), 0)::bigint
    into v_mine, v_total
    from public.ai_usage
   where created_at >= p_since;
  if v_mine + p_estimate > p_user_cap or v_total + p_estimate > p_global_cap then
    return null;
  end if;
  insert into public.ai_usage (user_id, day, purpose, cost_halalas)
  values (p_user, (now() at time zone 'utc')::date, p_purpose, p_estimate)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.ai_settle(
  p_id uuid, p_user uuid, p_input int, p_output int, p_cost bigint
) returns void
language sql
security definer
set search_path = public
as $$
  update public.ai_usage
     set input_tokens = greatest(p_input, 0), output_tokens = greatest(p_output, 0), cost_halalas = greatest(p_cost, 1)
   where id = p_id and user_id = p_user;
$$;

create or replace function public.ai_release(p_id uuid, p_user uuid) returns void
language sql
security definer
set search_path = public
as $$
  -- Only a reservation that was never settled (no tokens recorded) can be released.
  delete from public.ai_usage
   where id = p_id and user_id = p_user and input_tokens = 0 and output_tokens = 0;
$$;

revoke execute on function public.ai_reserve(uuid, text, bigint, bigint, bigint, timestamptz) from public, anon, authenticated;
revoke execute on function public.ai_settle(uuid, uuid, int, int, bigint) from public, anon, authenticated;
revoke execute on function public.ai_release(uuid, uuid) from public, anon, authenticated;
grant execute on function public.ai_reserve(uuid, text, bigint, bigint, bigint, timestamptz) to service_role;
grant execute on function public.ai_settle(uuid, uuid, int, int, bigint) to service_role;
grant execute on function public.ai_release(uuid, uuid) to service_role;

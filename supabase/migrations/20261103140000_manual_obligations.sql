-- Obligations added by hand (roadmap 2026-11-03): quarterly / yearly schedules, server-side validation,
-- and two functions the app calls to save and stop an obligation.

-- 1. Instances honour frequency (monthly is unchanged).
create or replace function public.refresh_obligation_instances(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  today date := (now() at time zone 'Asia/Riyadh')::date;
  o record;
  k int;
  p date;
  d date;
  wanted int;
  base date;
begin
  for o in
    select * from public.obligations
    where user_id = p_user and active
      and ((kind in ('fixed', 'loan', 'bill') and expected_amount_halalas is not null) or kind = 'card_statement')
  loop
    for k in (case when o.kind = 'bill' then -1 else 0 end)..(case when o.kind = 'bill' then 0 else 1 end) loop
      p := (date_trunc('month', today) + make_interval(months => k))::date;
      -- quarterly / yearly obligations only fall in the months counted from start_month (month 1 when unset)
      if o.frequency in ('quarterly', 'annual')
         and mod(extract(month from p)::int - coalesce((o.due_rule->>'start_month')::int, 1) + 12,
                 case when o.frequency = 'quarterly' then 3 else 12 end) <> 0 then
        continue;
      end if;
      wanted := coalesce((o.due_rule->>'day')::int, (o.due_rule->>'fallback_day')::int, 28);
      base := case when coalesce((o.due_rule->>'next_month')::boolean, false) then (p + interval '1 month')::date else p end;
      d := base + (least(greatest(wanted, 1), extract(day from (base + interval '1 month' - interval '1 day'))::int) - 1);
      if d + coalesce((o.due_rule->>'grace')::int, 0) >= today then
        insert into public.obligation_instances (user_id, obligation_id, period_start, due_date, expected_amount_halalas)
        values (p_user, o.id, p, d, o.expected_amount_halalas)
        on conflict (obligation_id, period_start) do nothing;
      end if;
    end loop;
  end loop;

  update public.obligation_instances i
  set status = 'overdue'
  from public.obligations ob
  where i.obligation_id = ob.id and i.user_id = p_user and i.status = 'pending'
    and i.due_date + coalesce((ob.due_rule->>'grace')::int, 0) < today;
end;
$$;
revoke execute on function public.refresh_obligation_instances(uuid) from public, anon, authenticated;
grant execute on function public.refresh_obligation_instances(uuid) to service_role;

-- 2. The client can write its own obligations directly (RLS), so the database enforces the limits too.
alter table public.obligations
  add constraint obligations_name_len check (char_length(name) between 1 and 60),
  add constraint obligations_lead_days_max check (lead_days <= 14),
  add constraint obligations_amount_max check (expected_amount_halalas is null or expected_amount_halalas <= 10000000000),
  add constraint obligations_due_rule_sane check (
    case when due_rule ? 'day' then (due_rule->>'day') ~ '^[0-9]{1,2}$' and (due_rule->>'day')::int between 1 and 31 else true end
    and case when due_rule ? 'grace' then (due_rule->>'grace') ~ '^[0-9]{1,2}$' and (due_rule->>'grace')::int between 0 and 14 else true end
    and case when due_rule ? 'start_month' then (due_rule->>'start_month') ~ '^[0-9]{1,2}$' and (due_rule->>'start_month')::int between 1 and 12 else true end
  );

-- 3. Save (create when p_id is null, otherwise edit) one obligation of the signed-in user. Runs with the caller's
--    rights, so RLS keeps it to their own rows and categories.
create or replace function public.save_my_obligation(p_id uuid, p jsonb)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p->>'name', ''));
  v_kind text := p->>'kind';
  v_type text := coalesce(p->>'amount_type', 'fixed');
  v_freq text := coalesce(p->>'frequency', 'monthly');
  v_amount bigint := nullif(p->>'amount_halalas', '')::bigint;
  v_day int := (p->>'day')::int;
  v_start int := nullif(p->>'start_month', '')::int;
  v_grace int := coalesce((p->>'grace')::int, 3);
  v_lead int := coalesce((p->>'lead_days')::int, 2);
  v_cat uuid := nullif(p->>'category_id', '')::uuid;
  v_tol int := coalesce((p->>'tolerance_pct')::int, 10);
  v_auto boolean := coalesce((p->>'auto_merchant')::boolean, false);
  v_words jsonb := coalesce(p->'merchant', '[]'::jsonb);
  v_old public.obligations;
  v_rule jsonb;
  v_match jsonb;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  if char_length(v_name) not between 1 and 60 then raise exception 'bad name'; end if;
  if v_kind not in ('bill', 'fixed', 'loan') then raise exception 'bad kind'; end if;
  if v_type not in ('fixed', 'estimated') then raise exception 'bad amount type'; end if;
  if v_freq not in ('monthly', 'quarterly', 'annual') then raise exception 'bad frequency'; end if;
  if v_amount is null and v_kind <> 'bill' then raise exception 'amount required'; end if;
  if v_amount is not null and (v_amount <= 0 or v_amount > 10000000000) then raise exception 'bad amount'; end if;
  if v_day is null or v_day not between 1 and 31 then raise exception 'bad day'; end if;
  if v_freq <> 'monthly' and (v_start is null or v_start not between 1 and 12) then raise exception 'bad start month'; end if;
  if v_grace not between 0 and 14 or v_lead not between 0 and 14 then raise exception 'bad days'; end if;
  if v_tol not between 0 and 50 then raise exception 'bad tolerance'; end if;
  if jsonb_typeof(v_words) <> 'array' or jsonb_array_length(v_words) > 5
     or exists (select 1 from jsonb_array_elements(v_words) w
                where jsonb_typeof(w) <> 'string' or char_length(w #>> '{}') not between 1 and 30) then
    raise exception 'bad match words';
  end if;
  if v_cat is not null and not exists (select 1 from public.categories where id = v_cat) then
    raise exception 'unknown category';
  end if;

  if p_id is not null then
    select * into v_old from public.obligations where id = p_id and user_id = auth.uid();
    if not found then raise exception 'not found'; end if;
    if v_old.kind = 'card_statement' then raise exception 'statement obligations cannot be edited'; end if;
  end if;

  -- a salary-linked obligation keeps its link: the day then acts as the fallback day
  v_rule := (coalesce(v_old.due_rule, '{}'::jsonb) - 'start_month')
    || jsonb_build_object('day', v_day, 'grace', v_grace);
  if v_rule ? 'after' then v_rule := v_rule || jsonb_build_object('fallback_day', v_day); end if;
  if v_freq <> 'monthly' then v_rule := v_rule || jsonb_build_object('start_month', v_start); end if;
  v_match := coalesce(v_old.match, '{}'::jsonb) - 'merchant' - 'auto_merchant';
  if jsonb_array_length(v_words) > 0 then
    v_match := v_match || jsonb_build_object('merchant', v_words, 'auto_merchant', v_auto, 'tolerance_pct', v_tol);
  elsif v_old.match ? 'tolerance_pct' then
    v_match := v_match || jsonb_build_object('tolerance_pct', coalesce((p->>'tolerance_pct')::int, (v_old.match->>'tolerance_pct')::int)); -- keep an exact (0) tolerance
  end if;

  if p_id is null then
    insert into public.obligations (name, category_id, kind, amount_type, expected_amount_halalas, frequency, due_rule, lead_days, match)
    values (v_name, v_cat, v_kind, v_type, v_amount, v_freq, v_rule, v_lead, v_match)
    returning id into v_id;
  else
    update public.obligations
    set name = v_name, category_id = v_cat, kind = v_kind, amount_type = v_type, expected_amount_halalas = v_amount,
        frequency = v_freq, due_rule = v_rule, lead_days = v_lead, match = v_match, active = true
    where id = p_id and user_id = auth.uid();
    v_id := p_id;
    -- open instances that nothing has touched follow the new details: those in months that are no longer on the
    -- schedule go, the rest get the new amount and due day (salary-linked ones keep the date the server set)
    delete from public.obligation_instances
    where obligation_id = p_id and status = 'pending' and match_state = 'none'
      and transaction_id is null and source_raw_message_id is null
      and v_freq <> 'monthly'
      and mod(extract(month from period_start)::int - coalesce(v_start, 1) + 12, case when v_freq = 'quarterly' then 3 else 12 end) <> 0;
    update public.obligation_instances i
    set expected_amount_halalas = v_amount,
        due_date = case when v_rule ? 'after' then i.due_date else
          (case when coalesce((v_rule->>'next_month')::boolean, false) then (i.period_start + interval '1 month')::date else i.period_start end)
          + (least(v_day, extract(day from ((case when coalesce((v_rule->>'next_month')::boolean, false) then (i.period_start + interval '1 month')::date else i.period_start end) + interval '1 month' - interval '1 day'))::int) - 1)
        end
    where i.obligation_id = p_id and i.status = 'pending' and i.match_state = 'none'
      and i.transaction_id is null and i.source_raw_message_id is null;
  end if;

  perform public.refresh_my_obligations();
  return v_id;
end;
$$;
revoke execute on function public.save_my_obligation(uuid, jsonb) from public, anon;
grant execute on function public.save_my_obligation(uuid, jsonb) to authenticated;

-- 4. Stop tracking: paid and skipped history stays, open and late untouched instances go. Not for card statements.
create or replace function public.stop_my_obligation(p_id uuid)
returns void
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '28000'; end if;
  update public.obligations set active = false where id = p_id and user_id = auth.uid() and kind <> 'card_statement';
  if not found then raise exception 'not found'; end if;
  delete from public.obligation_instances
  where obligation_id = p_id and status in ('pending', 'overdue') and match_state = 'none'
    and transaction_id is null and source_raw_message_id is null;
end;
$$;
revoke execute on function public.stop_my_obligation(uuid) from public, anon;
grant execute on function public.stop_my_obligation(uuid) to authenticated;

-- Owner decision 2026-11-20 (paste a bill message): a bill can be created from a pasted bill notice, so
-- save_my_obligation accepts the line or account's last 4 (`line`, exactly 4 digits) and who sends the notices
-- (`biller`: 'stc', the default and the two seeded lines, or 'se', Saudi Electricity), plus `next_month` for a bill
-- due the month after it is issued. A bill form save that does not send `line` keeps the one the bill has.
-- One active bill per line and biller. Everything else is unchanged from 20261112200000.

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
  v_line text := nullif(btrim(coalesce(p->>'line', '')), '');
  v_biller text := coalesce(nullif(p->>'biller', ''), 'stc');
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
  -- A bill made from a pasted bill message: the line or account's last 4 and who sends the notices.
  if p ? 'line' and v_line is not null then
    if v_kind <> 'bill' then raise exception 'line only for bills'; end if;
    if v_line !~ '^[0-9]{4}$' then raise exception 'bad line'; end if;
    if v_biller not in ('stc', 'se') then raise exception 'bad biller'; end if;
    if exists (select 1 from public.obligations o
               where o.user_id = auth.uid() and o.active and o.kind = 'bill'
                 and o.id is distinct from p_id
                 and o.match->>'line' = v_line and coalesce(o.match->>'biller', 'stc') = v_biller) then
      raise exception 'line in use';
    end if;
  end if;
  if p ? 'next_month' and jsonb_typeof(p->'next_month') <> 'boolean' then raise exception 'bad next month'; end if;
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
  -- due the next month (a bill issued on the 20th, due on the 2nd): only set when the app sends it
  if p ? 'next_month' then v_rule := v_rule || jsonb_build_object('next_month', (p->>'next_month')::boolean); end if;
  v_match := coalesce(v_old.match, '{}'::jsonb) - 'merchant' - 'auto_merchant';
  -- the line is kept on edits that do not send it (the bill form never does)
  if p ? 'line' then
    v_match := v_match - 'line' - 'biller';
    if v_line is not null then
      v_match := v_match || jsonb_build_object('line', v_line, 'biller', v_biller);
    end if;
  end if;
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
    -- an amount changed by hand for one month (it no longer equals the old default) is kept
    update public.obligation_instances i
    set expected_amount_halalas = case
          when i.expected_amount_halalas is not distinct from v_old.expected_amount_halalas then v_amount
          else i.expected_amount_halalas end,
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

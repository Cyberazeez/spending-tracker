-- Bills (STC) and the card statement now show up in the obligations list before their SMS arrives,
-- so the owner always sees what is coming. The SMS (bill notice / statement notice) later fills in the
-- real amount and due date on the same instance (same obligation + period).
--
-- bill:            period = month the bill is issued; due = next month, day from due_rule; amount = the usual amount.
--                  Open periods: last month (still unpaid) and this month.
-- card_statement:  due on due_rule.day of this and next month; amount unknown until the statement SMS arrives.
-- fixed / loan:    unchanged (this month and next month).
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

-- Bills are created ahead by their issue day (owner rule 2026-11-05): a bill issued 1-19 gets this month and next,
-- one issued 20+ keeps last month and this month. Bills without an issue day now behave like the other obligations.

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
    -- A bill issued on the 1st-19th belongs to the month it is issued (this month and next are created ahead);
    -- one issued on the 20th or later (STC, the 27th) belongs to the next month, so last month's is still open.
    for k in (case when o.kind = 'bill' and coalesce((o.due_rule->>'issue_day')::int, 0) >= 20 then -1 else 0 end)
          ..(case when o.kind = 'bill' and coalesce((o.due_rule->>'issue_day')::int, 0) >= 20 then 0 else 1 end) loop
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

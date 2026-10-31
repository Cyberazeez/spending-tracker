-- Milestone 4: seed obligations and generate/overdue their instances.
-- Bill and card-statement instances are created by the ingest function from the SMS notice;
-- fixed and loan instances are generated here, only while they are not yet past due + grace (older history is not invented).

create unique index if not exists obligations_user_name_uidx on public.obligations (user_id, name);

create or replace function public.seed_obligations(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.obligations
    (user_id, name, category_id, kind, amount_type, expected_amount_halalas, frequency, due_rule, lead_days, match)
  select p_user, v.name, c.id, v.kind, v.amount_type, v.amount, 'monthly', v.due_rule::jsonb, v.lead, v.match::jsonb
  from (values
    ('Internet (STC 7356)',  'Utilities',  'bill',           'estimated', 17250,  '{"day":2,"next_month":true}',                         2,
      '{"line":"7356","merchant":["stc","saudi telecom"],"tolerance_pct":1}'),
    ('Mobile (STC 0569)',    'Utilities',  'bill',           'estimated', 27893,  '{"day":2,"next_month":true}',                         2,
      '{"line":"0569","merchant":["stc","saudi telecom"],"tolerance_pct":1}'),
    ('Horse and foal',       'Horse',      'fixed',          'fixed',     180000, '{"after":"salary","fallback_day":28,"grace":3}',      2,
      '{"types":["transfer_out"],"counterparty_last4":"7892","tolerance_pct":0}'),
    ('House Card top-up',    'House Card', 'fixed',          'fixed',     50000,  '{"day":2,"grace":3}',                                 2,
      '{"types":["transfer_out","wallet_topup"],"counterparty_last4":"8920","merchant":["d360"],"tolerance_pct":0}'),
    ('Murabahah installment','Loans',      'loan',           'fixed',     385833, '{"day":28,"grace":2}',                                3,
      '{"types":["loan_installment"],"accumulate":true}'),
    ('Credit card 8119 statement', 'Other', 'card_statement', 'estimated', null,  '{"day":25}',                                           3,
      '{"card":"8119","counterparty_last4":"8119","merchant":["alinma"],"types":["transfer_out","card_payment"],"tolerance_pct":1}')
  ) as v(name, cat, kind, amount_type, amount, due_rule, lead, match)
  left join public.categories c on c.user_id = p_user and c.name = v.cat
  on conflict (user_id, name) do nothing;
end;
$$;
revoke execute on function public.seed_obligations(uuid) from public, anon, authenticated;
grant execute on function public.seed_obligations(uuid) to service_role;

-- New users get them too. Trigger names run alphabetically, so this one fires after the category seed.
create or replace function public.handle_new_user_obligations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_obligations(new.id);
  return new;
end;
$$;
revoke execute on function public.handle_new_user_obligations() from public, anon, authenticated;
grant execute on function public.handle_new_user_obligations() to supabase_auth_admin;

create trigger on_auth_user_created_z_obligations
  after insert on auth.users
  for each row execute function public.handle_new_user_obligations();

-- Creates this and next month's instances for scheduled obligations (fixed, loan) that are still ahead, and marks
-- pending instances overdue once due date + grace has passed. Safe to call any number of times.
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
begin
  for o in
    select * from public.obligations
    where user_id = p_user and active and kind in ('fixed', 'loan') and expected_amount_halalas is not null
  loop
    for k in 0..1 loop
      p := (date_trunc('month', today) + make_interval(months => k))::date;
      wanted := coalesce((o.due_rule->>'day')::int, (o.due_rule->>'fallback_day')::int, 28);
      d := p + (least(greatest(wanted, 1), extract(day from (p + interval '1 month' - interval '1 day'))::int) - 1);
      -- still creatable up to its grace days late, so a payment made just after the due date finds its instance
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

-- What the app calls: only ever acts for the signed-in user.
create or replace function public.refresh_my_obligations()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  perform public.refresh_obligation_instances(auth.uid());
end;
$$;
revoke execute on function public.refresh_my_obligations() from public, anon;
grant execute on function public.refresh_my_obligations() to authenticated;

select public.seed_obligations(id) from auth.users;

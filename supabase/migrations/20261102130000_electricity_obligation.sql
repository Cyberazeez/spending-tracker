-- Electricity (SEC) is an obligation too: issued on the 28th each month, amount varies (last two bills 658 and 726 SAR).
-- Shown with the middle of the range (692 SAR) and a "usually 658-726" note. No bill-notice parser yet: that needs a real SMS template.
-- Bill period = the month it is issued; due on the 28th, 7 days of grace because the bill often reaches the owner late.
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
      '{"line":"7356","merchant":["stc","saudi telecom"],"auto_merchant":true,"tolerance_pct":1}'),
    ('Mobile (STC 0569)',    'Utilities',  'bill',           'estimated', 27893,  '{"day":2,"next_month":true}',                         2,
      '{"line":"0569","merchant":["stc","saudi telecom"],"auto_merchant":true,"tolerance_pct":1}'),
    ('Electricity (SEC)',   'Utilities',  'bill',           'estimated', 69200,  '{"day":28,"grace":7}',                                2,
      '{"merchant":["saudi electricity"],"auto_merchant":true,"tolerance_pct":6,"range":{"min_halalas":65800,"max_halalas":72600}}'),
    ('Horse and foal',       'Horse',      'fixed',          'fixed',     180000, '{"after":"salary","fallback_day":28,"grace":3}',      2,
      '{"types":["transfer_out"],"counterparty_last4":"7892","tolerance_pct":0}'),
    ('House Card top-up',    'House Card', 'fixed',          'fixed',     50000,  '{"day":2,"grace":3}',                                 2,
      '{"types":["transfer_out","wallet_topup"],"counterparty_last4":"8920","merchant":["d360"],"auto_merchant":true,"tolerance_pct":0}'),
    ('Murabahah installment','Loans',      'loan',           'fixed',     385833, '{"day":28,"grace":2}',                                3,
      '{"types":["loan_installment"],"accumulate":true}'),
    ('Credit card 8119 statement', 'Other', 'card_statement', 'estimated', null,  '{"day":25}',                                           3,
      '{"card":"8119","counterparty_last4":"8119","merchant":["alinma"],"auto_merchant":true,"types":["transfer_out","card_payment"],"tolerance_pct":1,"plan":{"name":"Autopia","instalment_halalas":165350,"months":6,"first":"2026-10"}}')
  ) as v(name, cat, kind, amount_type, amount, due_rule, lead, match)
  left join public.categories c on c.user_id = p_user and c.name = v.cat
  on conflict (user_id, name) do nothing;
end;
$$;
revoke execute on function public.seed_obligations(uuid) from public, anon, authenticated;
grant execute on function public.seed_obligations(uuid) to service_role;

select public.seed_obligations(id) from auth.users;

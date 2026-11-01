-- 1. A Car category (the owner counts car purchases, service and insurance as car spending) with seed words.
-- 2. The Autopia card payment plan (9,921 SAR, 6 x 1,653.50 from the October 2026 statement) is recorded on the card
--    statement obligation as a note, because each instalment is already inside that statement's total due.

-- 0. The Dining category becomes "Cafes & Restaurants" (cafes, coffee shops, restaurants, bakeries, delivery).
update public.categories set name = 'Cafes & Restaurants', name_ar = 'مطاعم ومقاهي' where name = 'Dining';

insert into public.categories (user_id, name, name_ar, kind, excluded_from_spend, sort_order)
select id, 'Car', 'سيارة', 'spend', false, 19 from auth.users
on conflict (user_id, name) do nothing;

create or replace function public.seed_merchant_rules(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select * from (values
      ('Cafes & Restaurants', 'hungerstation'), ('Cafes & Restaurants', 'jahez'), ('Cafes & Restaurants', 'mcdonalds'), ('Cafes & Restaurants', 'kudu'),
      ('Cafes & Restaurants', 'albaik'), ('Cafes & Restaurants', 'al baik'), ('Cafes & Restaurants', 'herfy'), ('Cafes & Restaurants', 'otten'),
      ('Cafes & Restaurants', 'starbucks'), ('Cafes & Restaurants', 'tim hortons'), ('Cafes & Restaurants', 'burger king'), ('Cafes & Restaurants', 'dominos'),
      ('Cafes & Restaurants', 'pizza hut'), ('Cafes & Restaurants', 'kfc'), ('Cafes & Restaurants', 'go greek'),
      ('Groceries',     'lulu'), ('Groceries', 'panda'), ('Groceries', 'tamim'), ('Groceries', 'danube'),
      ('Groceries',     'othaim'), ('Groceries', 'carrefour'),
      ('Fuel',          'aldrees'), ('Fuel', 'aramco'), ('Fuel', 'sasco'), ('Fuel', 'petromin'),
      ('Transport',     'uber'), ('Transport', 'careem'), ('Transport', 'bolt'),
      ('Shopping',      'noon'), ('Shopping', 'amazon'), ('Shopping', 'extra'), ('Shopping', 'jarir'),
      ('Shopping',      'ikea'), ('Shopping', 'shein'), ('Shopping', 'namshi'),
      ('Subscriptions', 'apple com bill'), ('Subscriptions', 'youtubepremium'), ('Subscriptions', 'netflix'),
      ('Subscriptions', 'spotify'), ('Subscriptions', 'shahid'), ('Subscriptions', 'openai'),
      ('Subscriptions', 'cloudflare'), ('Subscriptions', 'aws'), ('Subscriptions', 'google'),
      ('Health',        'nahdi'), ('Health', 'al dawaa'), ('Health', 'aldawaa'),
      ('Entertainment', 'vox'), ('Entertainment', 'muvi'),

      ('Cafes & Restaurants', 'restaurant'), ('Cafes & Restaurants', 'resturant'), ('Cafes & Restaurants', 'cafe'), ('Cafes & Restaurants', 'coffee'),
      ('Cafes & Restaurants', 'bakery'), ('Cafes & Restaurants', 'pastries'), ('Cafes & Restaurants', 'burger'), ('Cafes & Restaurants', 'burgerizzr'),
      ('Cafes & Restaurants', 'sushi'), ('Cafes & Restaurants', 'papajohns'), ('Cafes & Restaurants', 'popeyes'), ('Cafes & Restaurants', 'dunkin'),
      ('Cafes & Restaurants', 'mcdonald'), ('Cafes & Restaurants', 'mc donalds'), ('Cafes & Restaurants', 'ninja'), ('Cafes & Restaurants', 'hungerstation'),
      ('Groceries',     'saudi marketing'), ('Groceries', 'saudi markiting'), ('Groceries', 'saudi farm'),
      ('Groceries',     'farm superstore'),
      ('Fuel',          'adnoc'), ('Fuel', 'sahel'), ('Fuel', 'hala saudi petroleum'), ('Fuel', 'naft'),
      ('Fuel',          'al drees'), ('Fuel', 'mazaya'),
      ('Travel',        'saudi airlines'), ('Travel', 'trip com'), ('Travel', 'eurostar'),
      ('Travel',        'lumi rental'), ('Travel', 'extime'),
      ('Utilities',     'saudi electricity'), ('Utilities', 'stc postpaid'), ('Utilities', 'mobily'), ('Utilities', 'zain'),
      ('Entertainment', 'amc'), ('Entertainment', 'reel cinemas'), ('Entertainment', 'cinema'),
      ('Shopping',      'north face'), ('Shopping', 'fred perry'), ('Shopping', 'massimo dutti'),
      ('Shopping',      'body shop'), ('Shopping', 'columbia'),
      ('Car',           'mohamed yousuf naghi'), ('Car', 'autopia'), ('Car', 'almajdouie'), ('Car', 'universal motors'),
      ('Car',           'tawuniya'), ('Car', 'walaa'), ('Car', 'united insurance'),
      ('Travel',        'saudia'), ('Travel', 'flynas'), ('Travel', 'flyadeal'), ('Travel', 'booking com')
    ) as t(category, pattern)
  loop
    insert into public.merchant_rules (user_id, pattern, match_type, category_id, status, source)
    select p_user, r.pattern, 'contains', c.id, 'confirmed', 'seed'
    from public.categories c where c.user_id = p_user and c.name = r.category
    on conflict (user_id, pattern, match_type) do nothing;
  end loop;

  -- The horse housing payee and the House Card are specific to this household.
  insert into public.merchant_rules (user_id, pattern, match_type, category_id, status, source)
  select p_user, 'acct:7892', 'exact', c.id, 'confirmed', 'seed' from public.categories c where c.user_id = p_user and c.name = 'Horse'
  on conflict (user_id, pattern, match_type) do nothing;
  insert into public.merchant_rules (user_id, pattern, match_type, category_id, status, source)
  select p_user, 'card:8920', 'exact', c.id, 'confirmed', 'seed' from public.categories c where c.user_id = p_user and c.name = 'House Card'
  on conflict (user_id, pattern, match_type) do nothing;
end;
$$;
revoke execute on function public.seed_merchant_rules(uuid) from public, anon, authenticated;
grant execute on function public.seed_merchant_rules(uuid) to service_role;

create or replace function public.seed_defaults(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.settings (user_id) values (p_user) on conflict do nothing;

  insert into public.categories (user_id, name, name_ar, kind, excluded_from_spend, sort_order) values
    (p_user, 'Groceries',      'بقالة',            'spend',    false, 1),
    (p_user, 'Cafes & Restaurants', 'مطاعم ومقاهي', 'spend', false, 2),
    (p_user, 'Fuel',           'وقود',             'spend',    false, 3),
    (p_user, 'Utilities',      'فواتير',           'spend',    false, 4),
    (p_user, 'Rent/Housing',   'سكن',              'spend',    false, 5),
    (p_user, 'Horse',          'الخيل',            'spend',    false, 6),
    (p_user, 'Transport',      'مواصلات',          'spend',    false, 7),
    (p_user, 'Shopping',       'تسوق',             'spend',    false, 8),
    (p_user, 'Subscriptions',  'اشتراكات',         'spend',    false, 9),
    (p_user, 'Health',         'صحة',              'spend',    false, 10),
    (p_user, 'Entertainment',  'ترفيه',            'spend',    false, 11),
    (p_user, 'Travel',         'سفر',              'spend',    false, 12),
    (p_user, 'House Card',     'بطاقة البيت',      'spend',    false, 13),
    (p_user, 'Transfers',      'تحويلات',          'transfer', true,  14),
    (p_user, 'Fees',           'رسوم',             'fee',      false, 15),
    (p_user, 'Income',         'دخل',              'income',   true,  16),
    (p_user, 'Other',          'أخرى',             'spend',    false, 17),
    (p_user, 'Loans',          'قروض',             'spend',    false, 18),
    (p_user, 'Car',            'سيارة',            'spend',    false, 19)
  on conflict (user_id, name) do nothing;

  insert into public.own_accounts (user_id, bank, last4, kind, label, is_active, is_house_card) values
    (p_user, 'alrajhi', '6331', 'account',     'Al Rajhi account',          true,  false),
    (p_user, 'alrajhi', '1271', 'debit_card',  'Al Rajhi mada card',        true,  false),
    (p_user, 'snb',     '0102', 'account',     'SNB account',               true,  false),
    (p_user, 'snb',     '0103', 'account',     'SNB account',               true,  false),
    (p_user, 'snb',     '3301', 'debit_card',  'SNB mada card',             true,  false),
    (p_user, 'alinma',  '6000', 'account',     'Alinma main account',       true,  false),
    (p_user, 'alinma',  '6698', 'debit_card',  'Alinma mada card',          true,  false),
    (p_user, 'alinma',  '8119', 'credit_card', 'Alinma credit card (daily)', true, false),
    (p_user, 'd360',    '5911', 'account',     'D360 account',              true,  false),
    (p_user, 'd360',    '0513', 'account',     'D360 account',              true,  false),
    (p_user, 'd360',    '7705', 'debit_card',  'D360 card',                 true,  false),
    (p_user, 'd360',    '8920', 'debit_card',  'House Card',                true,  true),
    (p_user, 'd360',    '5745', 'debit_card',  'D360 card (cancelled)',     false, false),
    (p_user, 'barq',    '1224', 'debit_card',  'barq virtual card',         true,  false),
    (p_user, 'barq',    '9105', 'debit_card',  'barq Apple Pay card',       true,  false),
    (p_user, 'barq',    '1345', 'wallet',      'barq wallet',               true,  false),
    (p_user, 'stc',     '6190', 'debit_card',  'STC Bank card',             true,  false)
  on conflict (user_id, bank, last4) do nothing;

  perform public.seed_merchant_rules(p_user);
end;
$$;

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

select public.seed_merchant_rules(id) from auth.users;

update public.obligations
set match = match || '{"plan":{"name":"Autopia","instalment_halalas":165350,"months":6,"first":"2026-10"}}'::jsonb
where kind = 'card_statement' and match->>'card' = '8119';

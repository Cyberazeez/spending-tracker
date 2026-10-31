-- Milestone 3: card number on transactions (House Card rule), a Loans category, and seed merchant rules.

alter table public.transactions add column card_last4 text;

-- New category for loan instalments, for existing users and for new ones (see seed_defaults below).
insert into public.categories (user_id, name, name_ar, kind, excluded_from_spend, sort_order)
select id, 'Loans', 'قروض', 'spend', false, 18 from auth.users
on conflict (user_id, name) do nothing;

-- "contains" rules match whole words by prefix: "mcdonalds" matches "MCDONALDS1", "uber" matches "UBER ONE".
-- "acct:XXXX" / "card:XXXX" (match_type exact) match the counterparty account / the card used.
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
      ('Dining',        'hungerstation'), ('Dining', 'jahez'), ('Dining', 'mcdonalds'), ('Dining', 'kudu'),
      ('Dining',        'albaik'), ('Dining', 'al baik'), ('Dining', 'herfy'), ('Dining', 'otten'),
      ('Dining',        'starbucks'), ('Dining', 'tim hortons'), ('Dining', 'burger king'), ('Dining', 'dominos'),
      ('Dining',        'pizza hut'), ('Dining', 'kfc'), ('Dining', 'go greek'),
      ('Groceries',     'lulu'), ('Groceries', 'panda'), ('Groceries', 'tamimi'), ('Groceries', 'danube'),
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

-- New users get the Loans category and the seed rules too.
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
    (p_user, 'Dining',         'مطاعم',            'spend',    false, 2),
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
    (p_user, 'Loans',          'قروض',             'spend',    false, 18)
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

-- Existing users (the owner): add the seed rules now.
select public.seed_merchant_rules(id) from auth.users;

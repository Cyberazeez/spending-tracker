-- Default settings, categories and own accounts, created when the owner user is added.

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
    (p_user, 'Other',          'أخرى',             'spend',    false, 17)
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
end;
$$;

revoke execute on function public.seed_defaults(uuid) from public, anon, authenticated;
grant execute on function public.seed_defaults(uuid) to service_role;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_defaults(new.id);
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.handle_new_user() to supabase_auth_admin;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

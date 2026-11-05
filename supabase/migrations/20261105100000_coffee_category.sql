-- A Coffee category for everyone (owner request 2026-11-05): existing accounts get it, new accounts are seeded with it.

insert into public.categories (user_id, name, name_ar, kind, excluded_from_spend, sort_order)
select id, 'Coffee', 'قهوة', 'spend', false, 20 from auth.users
on conflict (user_id, name) do nothing;

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
    (p_user, 'Transport',      'مواصلات',          'spend',    false, 7),
    (p_user, 'Shopping',       'تسوق',             'spend',    false, 8),
    (p_user, 'Subscriptions',  'اشتراكات',         'spend',    false, 9),
    (p_user, 'Health',         'صحة',              'spend',    false, 10),
    (p_user, 'Entertainment',  'ترفيه',            'spend',    false, 11),
    (p_user, 'Travel',         'سفر',              'spend',    false, 12),
    (p_user, 'Transfers',      'تحويلات',          'transfer', true,  14),
    (p_user, 'Fees',           'رسوم',             'fee',      false, 15),
    (p_user, 'Income',         'دخل',              'income',   true,  16),
    (p_user, 'Other',          'أخرى',             'spend',    false, 17),
    (p_user, 'Loans',          'قروض',             'spend',    false, 18),
    (p_user, 'Car',            'سيارة',            'spend',    false, 19),
    (p_user, 'Coffee',         'قهوة',             'spend',    false, 20)
  on conflict (user_id, name) do nothing;

  -- Rules that point at a category the account does not have (Horse, House Card) simply insert nothing.
  perform public.seed_merchant_rules(p_user);
end;
$$;
revoke execute on function public.seed_defaults(uuid) from public, anon, authenticated;
grant execute on function public.seed_defaults(uuid) to service_role;

-- Owner decision 2026-11-13: money sent to other people and filed under Transfers by hand counts as spending.
-- Moves between the owner's own accounts stay out of spending because they are flagged on the transaction itself
-- (is_internal / excluded_from_spend): wallet top-ups, credit card payoffs, matched transfer pairs and transfers to a
-- saved own account (docs/superpowers/specs/2026-11-08-transfer-review-design.md). The category no longer hides
-- anything by itself. Income stays excluded.
-- Checked read-only on production first: every internal row in Transfers already carries is_internal = true; the
-- rows that start counting are the owner's manually filed transfers out.

update public.categories set excluded_from_spend = false where name = 'Transfers' and excluded_from_spend;

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
    (p_user, 'Transfers',      'تحويلات',          'transfer', false, 14),
    (p_user, 'Fees',           'رسوم',             'fee',      false, 15),
    (p_user, 'Income',         'دخل',              'income',   true,  16),
    (p_user, 'Other',          'أخرى',             'spend',    false, 17),
    (p_user, 'Loans',          'قروض',             'spend',    false, 18),
    (p_user, 'Car',            'سيارة',            'spend',    false, 19),
    (p_user, 'Coffee',         'قهوة',             'spend',    false, 20),
    (p_user, 'Hotel',          'فنادق',            'spend',    false, 21),
    (p_user, 'Education', 'تعليم', 'spend', false, 22),
    (p_user, 'Family & Kids', 'العائلة والأطفال', 'spend', false, 23),
    (p_user, 'Gifts & Charity', 'هدايا وصدقات', 'spend', false, 24),
    (p_user, 'Pets', 'حيوانات أليفة', 'spend', false, 25),
    (p_user, 'Personal care', 'عناية شخصية', 'spend', false, 26),
    (p_user, 'Insurance', 'تأمين', 'spend', false, 27),
    (p_user, 'Government & fees', 'رسوم حكومية', 'spend', false, 28)
  on conflict (user_id, name) do nothing;

  -- Rules that point at a category the account does not have (Horse, House Card) simply insert nothing.
  perform public.seed_merchant_rules(p_user);
end;
$$;
revoke execute on function public.seed_defaults(uuid) from public, anon, authenticated;
grant execute on function public.seed_defaults(uuid) to service_role;

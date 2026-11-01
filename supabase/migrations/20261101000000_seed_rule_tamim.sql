-- Banks truncate merchant names ("S106 TAMIM"), so the seed rule is the shorter word "tamim", which still matches
-- "tamimi" as a whole-word prefix. Also categorises what is already stored.

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

select public.seed_merchant_rules(id) from auth.users;

update public.transactions t
set category_id = r.category_id, category_source = 'rule', rule_id = r.id
from public.merchant_rules r
where r.user_id = t.user_id and r.pattern = 'tamim' and r.match_type = 'contains'
  and t.category_id is null and t.is_internal = false and t.type = 'purchase'
  and t.merchant_norm ~ '(^| )tamim';

-- More seed words for common Saudi merchants (found when importing real card statements).

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

      ('Dining',        'restaurant'), ('Dining', 'resturant'), ('Dining', 'cafe'), ('Dining', 'coffee'),
      ('Dining',        'bakery'), ('Dining', 'pastries'), ('Dining', 'burger'), ('Dining', 'burgerizzr'),
      ('Dining',        'sushi'), ('Dining', 'papajohns'), ('Dining', 'popeyes'), ('Dining', 'dunkin'),
      ('Dining',        'mcdonald'), ('Dining', 'mc donalds'), ('Dining', 'ninja'), ('Dining', 'hungerstation'),
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

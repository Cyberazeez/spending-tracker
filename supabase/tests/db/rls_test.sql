-- RLS isolation test. Runs in one transaction and always rolls back (it raises at the end).
-- Success is the error message 'RLS_TESTS_OK'. Any other error message is a failed assertion.
-- Run: supabase db query < this file  (or the Supabase SQL editor / MCP execute_sql)

do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  b uuid := '00000000-0000-0000-0000-00000000000b';
  f uuid := '00000000-0000-0000-0000-0000000000f1';
  g uuid := '00000000-0000-0000-0000-0000000000f2';
  h uuid := '00000000-0000-0000-0000-0000000000f3';
  a_ob uuid;
  n int;
  denied boolean;
begin
  insert into auth.users (id, aud, role, email) values
    (a, 'authenticated', 'authenticated', 'rls-a@example.test'),
    (b, 'authenticated', 'authenticated', 'rls-b@example.test'),
    (f, 'authenticated', 'authenticated', 'rls-family@example.test');

  -- A and B stand for the owner (household extras are seeded by hand); F is a family member who signed up.
  perform public.seed_owner_extras(a);
  perform public.seed_owner_extras(b);

  -- a fresh sign-up starts clean: generic categories, no bank accounts, no obligations, none of the owner's rules
  select count(*) into n from public.categories where user_id = f;
  if n <> 26 then raise exception 'signup: expected 26 generic categories, got %', n; end if;
  select count(*) into n from public.categories where user_id = f and name in ('Horse', 'House Card');
  if n <> 0 then raise exception 'signup: household categories leaked to a new user'; end if;
  select count(*) into n from public.own_accounts where user_id = f;
  if n <> 0 then raise exception 'signup: a new user got bank accounts'; end if;
  select count(*) into n from public.obligations where user_id = f;
  if n <> 0 then raise exception 'signup: a new user got the owner''s obligations'; end if;
  select count(*) into n from public.merchant_rules where user_id = f and pattern in ('acct:7892', 'card:8920');
  if n <> 0 then raise exception 'signup: household merchant rules leaked'; end if;
  select count(*) into n from public.merchant_rules where user_id = f;
  if n < 40 then raise exception 'signup: the generic merchant rules are missing (%)', n; end if;
  select count(*) into n from public.settings where user_id = f and ai_enabled = false;
  if n <> 1 then raise exception 'signup: settings missing or AI not off'; end if;
  select count(*) into n from public.settings where user_id = f and ai_allowed = false and ai_monthly_cap_halalas = 0;
  if n <> 1 then raise exception 'signup: a new user is allowed AI or has a budget'; end if;

  -- trigger seeded both users
  select count(*) into n from public.categories where user_id in (a, b);
  if n <> 56 then raise exception 'seed: expected 56 categories, got %', n; end if;
  select count(*) into n from public.merchant_rules where user_id = a;
  if n < 50 then raise exception 'seed: expected the seed merchant rules, got %', n; end if;
  select count(*) into n from public.merchant_rules mr join public.categories c on c.id = mr.category_id where mr.user_id = a and c.user_id <> a;
  if n <> 0 then raise exception 'seed rule points at another user category'; end if;
  select count(*) into n from public.merchant_rules mr join public.categories c on c.id = mr.category_id
    where mr.user_id = a and c.name = 'Car' and mr.pattern in ('tawuniya', 'autopia');
  if n <> 2 then raise exception 'seed: car rules missing'; end if;
  select count(*) into n from public.obligations where user_id = a and match ? 'plan';
  if n <> 1 then raise exception 'seed: the statement obligation should carry the payment plan note'; end if;
  select count(*) into n from public.own_accounts where user_id = a;
  if n <> 17 then raise exception 'seed: expected 17 own_accounts for A, got %', n; end if;

  select count(*) into n from public.obligations where user_id in (a, b);
  if n <> 14 then raise exception 'seed: expected 14 obligations, got %', n; end if;

  insert into public.ingest_tokens (user_id, token_hash) values (a, 'hash-a'), (b, 'hash-b');
  insert into public.raw_messages (user_id, sender, body, received_at, dedupe_hash)
    values (a, 'alinma', 'body-a', now(), 'h-a'), (b, 'alinma', 'body-b', now(), 'h-b');
  insert into public.ai_usage (user_id, day, purpose) values (a, current_date, 'parse');

  -- act as user A
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from public.categories;
  if n <> 28 then raise exception 'A sees % categories, expected 28', n; end if;
  select count(*) into n from public.raw_messages;
  if n <> 1 then raise exception 'A sees % raw_messages, expected 1', n; end if;
  select count(*) into n from public.settings;
  if n <> 1 then raise exception 'A sees % settings rows, expected 1', n; end if;

  -- cannot insert a row for B
  denied := false;
  begin
    insert into public.budgets (user_id, category_id, monthly_limit_halalas)
      values (b, (select id from public.categories limit 1), 1000);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A inserted a budget for B'; end if;

  -- cannot update or delete B's rows (they are invisible, so 0 rows)
  update public.own_accounts set label = 'hacked' where user_id = b;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'A updated % rows of B', n; end if;
  delete from public.own_accounts where user_id = b;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'A deleted % rows of B', n; end if;

  -- token hash is never readable, metadata is
  denied := false;
  begin perform token_hash from public.ingest_tokens; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A could read token_hash'; end if;
  select count(*) into n from (select id, label, last_used_at from public.ingest_tokens) s;
  if n <> 1 then raise exception 'A sees % token rows, expected 1', n; end if;

  -- service-role-only tables
  denied := false;
  begin perform 1 from public.ai_usage; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A could read ai_usage'; end if;
  denied := false;
  begin perform 1 from public.rate_limits; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A could read rate_limits'; end if;

  -- raw_messages: body is immutable from the client, review fields are not
  denied := false;
  begin update public.raw_messages set body = 'edited'; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A edited a raw message body'; end if;
  denied := false;
  begin insert into public.raw_messages (user_id, sender, body, received_at, dedupe_hash) values (a, 'x', 'y', now(), 'z');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A inserted a raw message'; end if;
  update public.raw_messages set parse_status = 'ignored', ignore_reason = 'not_a_transaction';

  -- rate limiter and seed functions are not callable by users
  denied := false;
  begin perform public.bump_rate_limit(a, 'ingest_min', 'minute'); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called bump_rate_limit'; end if;
  denied := false;
  begin perform public.seed_defaults(a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called seed_defaults'; end if;

  denied := false;
  begin perform public.refresh_obligation_instances(a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called refresh_obligation_instances'; end if;
  denied := false;
  begin perform public.seed_obligations(a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called seed_obligations'; end if;

  -- the app's refresh only touches the caller's own obligations and is idempotent
  perform public.refresh_my_obligations();
  perform public.refresh_my_obligations();
  select count(*) into n from public.obligation_instances where user_id = a;
  if n < 3 then raise exception 'refresh created % instances for A, expected at least 3', n; end if;
  select count(*) into n from public.obligation_instances;
  if n <> (select count(*) from public.obligation_instances where user_id = a) then raise exception 'A sees instances of others'; end if;
  -- bills and the card statement are shown before their SMS arrives: bills with the usual amount, statements without one
  select count(*) into n from public.obligation_instances i join public.obligations o on o.id = i.obligation_id
    where o.kind = 'bill' and i.expected_amount_halalas is not null;
  if n < 2 then raise exception 'refresh created % bill instances, expected at least 2', n; end if;
  select count(*) into n from public.obligation_instances i join public.obligations o on o.id = i.obligation_id
    where o.kind = 'card_statement' and i.expected_amount_halalas is null;
  if n < 1 then raise exception 'refresh created no card statement instance'; end if;
  select count(*) into n from public.obligation_instances i join public.obligations o on o.id = i.obligation_id
    where i.due_date + coalesce((o.due_rule->>'grace')::int, 0) < (now() at time zone 'Asia/Riyadh')::date;
  if n <> 0 then raise exception 'refresh created instances in the past'; end if;
  select count(*) into n from (select obligation_id, period_start from public.obligation_instances group by 1, 2 having count(*) > 1) d;
  if n <> 0 then raise exception 'duplicate instances'; end if;

  -- obligations added by hand: monthly, quarterly and yearly schedules, validation, edit and stop
  declare
    q uuid; y uuid; m uuid; cat uuid;
    this_m int := extract(month from (now() at time zone 'Asia/Riyadh'))::int;
  begin
    select id into cat from public.categories where user_id = a limit 1;
    m := public.save_my_obligation(null, jsonb_build_object('name', 'Gym', 'kind', 'fixed', 'amount_type', 'fixed',
      'amount_halalas', 15000, 'frequency', 'monthly', 'day', 31, 'grace', 3, 'lead_days', 2, 'category_id', cat,
      'merchant', jsonb_build_array('gym club'), 'auto_merchant', false, 'tolerance_pct', 10));
    select count(*) into n from public.obligation_instances where obligation_id = m;
    if n < 1 then raise exception 'a monthly obligation made no instance'; end if;
    select count(*) into n from public.obligation_instances where obligation_id = m
      and due_date = (date_trunc('month', period_start) + interval '1 month - 1 day')::date and extract(day from due_date) <= 31;
    if n < 1 then raise exception 'day 31 was not clamped to the month end'; end if;

    -- quarterly: first due month is this month, so this month has an instance and next month does not
    q := public.save_my_obligation(null, jsonb_build_object('name', 'Insurance', 'kind', 'fixed', 'amount_type', 'fixed',
      'amount_halalas', 90000, 'frequency', 'quarterly', 'start_month', this_m, 'day', 28, 'grace', 14, 'lead_days', 2));
    select count(*) into n from public.obligation_instances where obligation_id = q
      and extract(month from period_start)::int = this_m;
    if n <> 1 then raise exception 'quarterly: expected this month''s instance, got %', n; end if;
    select count(*) into n from public.obligation_instances where obligation_id = q
      and extract(month from period_start)::int <> this_m;
    if n <> 0 then raise exception 'quarterly: made an instance in a month that is not due'; end if;

    -- yearly starting next month: nothing this month
    y := public.save_my_obligation(null, jsonb_build_object('name', 'Registration', 'kind', 'fixed', 'amount_type', 'fixed',
      'amount_halalas', 50000, 'frequency', 'annual', 'start_month', (this_m % 12) + 1, 'day', 28, 'grace', 14, 'lead_days', 2));
    select count(*) into n from public.obligation_instances where obligation_id = y
      and extract(month from period_start)::int = this_m;
    if n <> 0 then raise exception 'annual: instance in the wrong month'; end if;

    -- edit: the open instance is rebuilt with the new amount
    perform public.save_my_obligation(m, jsonb_build_object('name', 'Gym', 'kind', 'fixed', 'amount_type', 'fixed',
      'amount_halalas', 20000, 'frequency', 'monthly', 'day', 28, 'grace', 3, 'lead_days', 2));
    select count(*) into n from public.obligation_instances where obligation_id = m and expected_amount_halalas <> 20000;
    if n <> 0 then raise exception 'edit did not rebuild open instances'; end if;
    select count(*) into n from public.obligations where id = m and match ? 'merchant';
    if n <> 0 then raise exception 'edit without match words kept old words'; end if;

    -- editing the day moves the open instance without deleting it
    select count(*) into n from public.obligation_instances where obligation_id = m and extract(day from due_date) = 28;
    if n < 1 then raise exception 'edit did not move the due day of the open instance'; end if;
    -- a seeded salary-linked obligation keeps its link and a zero tolerance when edited
    perform public.save_my_obligation((select id from public.obligations where user_id = a and due_rule ? 'after' limit 1),
      jsonb_build_object('name', (select name from public.obligations where user_id = a and due_rule ? 'after' limit 1),
        'kind', 'fixed', 'amount_type', 'fixed', 'amount_halalas', 180000, 'frequency', 'monthly', 'day', 27, 'grace', 3));
    select count(*) into n from public.obligations where user_id = a and due_rule->>'after' = 'salary' and (due_rule->>'fallback_day')::int = 27;
    if n <> 1 then raise exception 'edit dropped the salary link'; end if;
    select count(*) into n from public.obligations where user_id = a and due_rule ? 'after' and (match->>'tolerance_pct')::int = 0;
    if n <> 1 then raise exception 'edit lost the zero tolerance'; end if;
    -- the card statement cannot be stopped
    denied := false;
    begin perform public.stop_my_obligation((select id from public.obligations where user_id = a and kind = 'card_statement' limit 1));
    exception when others then denied := true; end;
    if not denied then raise exception 'card statement was stopped';  end if;

    -- stop: inactive, open instances gone
    perform public.stop_my_obligation(m);
    select count(*) into n from public.obligations where id = m and active;
    if n <> 0 then raise exception 'stop left it active'; end if;
    select count(*) into n from public.obligation_instances where obligation_id = m and status = 'pending';
    if n <> 0 then raise exception 'stop left open instances'; end if;
    perform public.refresh_my_obligations();
    select count(*) into n from public.obligation_instances where obligation_id = m;
    if n <> 0 then raise exception 'a stopped obligation came back'; end if;

    -- validation
    denied := false;
    begin perform public.save_my_obligation(null, '{"name":"x","kind":"fixed","amount_halalas":100,"day":32}'::jsonb);
    exception when others then denied := true; end;
    if not denied then raise exception 'day 32 accepted'; end if;
    denied := false;
    begin perform public.save_my_obligation(null, '{"name":"x","kind":"card_statement","amount_halalas":100,"day":2}'::jsonb);
    exception when others then denied := true; end;
    if not denied then raise exception 'card_statement creatable'; end if;
    denied := false;
    begin perform public.save_my_obligation(null, '{"name":"x","kind":"fixed","day":2}'::jsonb);
    exception when others then denied := true; end;
    if not denied then raise exception 'fixed without amount accepted'; end if;
    denied := false;
    begin perform public.save_my_obligation(null, '{"name":"x","kind":"fixed","amount_halalas":100,"day":2,"frequency":"quarterly"}'::jsonb);
    exception when others then denied := true; end;
    if not denied then raise exception 'quarterly without start month accepted'; end if;
    denied := false;
    begin insert into public.obligations (name, kind, amount_type, expected_amount_halalas, due_rule)
      values ('x', 'fixed', 'fixed', 100, '{"day":99}'::jsonb);
    exception when check_violation then denied := true; end;
    if not denied then raise exception 'direct insert with day 99 accepted'; end if;
    -- another user's obligation can neither be edited nor stopped
    denied := false;
    begin perform public.stop_my_obligation((select id from public.obligations where user_id = b limit 1));
    exception when others then denied := true; end;
    if not denied then raise exception 'A stopped one of B''s obligations'; end if;
  end;

  denied := false;
  begin perform public.import_statement_rows(a, '[]'::jsonb); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called import_statement_rows'; end if;

  -- anon sees nothing

  -- settings: preferences are editable, the AI cap and row lifecycle are not
  update public.settings set ai_enabled = true, locale = 'ar';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'A could not update own settings preferences'; end if;
  update public.settings set monthly_budget_halalas = 800000;
  select count(*) into n from public.settings where monthly_budget_halalas = 800000;
  if n <> 1 then raise exception 'A could not set the monthly budget'; end if;
  denied := false;
  begin update public.settings set monthly_budget_halalas = 0; exception when check_violation then denied := true; end;
  if not denied then raise exception 'A set a zero monthly budget'; end if;
  denied := false;
  begin update public.settings set ai_monthly_cap_halalas = 999999999; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A raised their own AI cap'; end if;
  denied := false;
  begin update public.settings set ai_allowed = true; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A switched on their own paid AI flag'; end if;
  update public.settings set ai_parse_enabled = true;
  select count(*) into n from public.settings where ai_parse_enabled = true;
  if n <> 1 then raise exception 'A could not give their own consent for AI reading'; end if;
  denied := false;
  begin delete from public.settings; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A deleted settings'; end if;
  denied := false;
  begin insert into public.settings (user_id) values (a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A inserted settings'; end if;

  -- token rotation function is service-only
  denied := false;
  begin perform public.rotate_ingest_token(a, 'x', 'y'); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called rotate_ingest_token'; end if;
  denied := false;
  begin perform public.revoke_ingest_token(a, 'app'); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called revoke_ingest_token'; end if;

  reset role;
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  denied := false;
  begin perform 1 from public.transactions; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'anon could read transactions'; end if;

  reset role;

  -- a family member sees none of the owner's data, and cannot reach it through the app's functions
  a_ob := (select id from public.obligations where user_id = a limit 1);
  perform set_config('request.jwt.claims', json_build_object('sub', f, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.own_accounts;
  if n <> 0 then raise exception 'F sees bank accounts'; end if;
  select count(*) into n from public.obligations;
  if n <> 0 then raise exception 'F sees obligations'; end if;
  select count(*) into n from public.merchant_rules where pattern like 'acct:%' or pattern like 'card:%';
  if n <> 0 then raise exception 'F sees household rules'; end if;
  select count(*) into n from public.categories;
  if n <> 26 then raise exception 'F sees % categories, expected only their own 26', n; end if;
  select count(*) into n from public.settings;
  if n <> 1 then raise exception 'F sees % settings rows', n; end if;
  denied := false;
  begin perform public.stop_my_obligation(a_ob); exception when others then denied := (sqlerrm = 'not found'); end;
  if not denied then raise exception 'F could stop one of the owner''s obligations (or got another error)'; end if;
  denied := false;
  begin perform public.seed_owner_extras(f); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'F called seed_owner_extras'; end if;
  denied := false;
  begin perform public.ai_spend_summary(f, now() - interval '1 day'); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'F called ai_spend_summary'; end if;
  reset role;
  select count(*) into n from public.obligations where id = a_ob and active;
  if n <> 1 then raise exception 'the owner''s obligation changed'; end if;

  -- AI spend is summed per user and over everybody
  insert into public.ai_usage (user_id, day, purpose, cost_halalas) values (a, current_date, 'insights', 7), (f, current_date, 'insights', 5);
  select count(*) into n from public.ai_spend_summary(a, date_trunc('month', now())) s where s.mine_halalas >= 7 and s.total_halalas >= s.mine_halalas + 5;
  if n <> 1 then raise exception 'ai_spend_summary wrong'; end if;
  select count(*) into n from public.settings where user_id = f and base_salary_halalas = 0;
  if n <> 1 then raise exception 'a new user inherited the owner''s salary'; end if;
  -- statement import: rows land as csv history, categories map by name, a second import changes nothing
  n := public.import_statement_rows(a, '[{"ref":"alinma:8119:1:1","date":"2026-05-19","type":"purchase","direction":"out","amount":2740,"merchant":"LULU","norm":"lulu","category":"Groceries","card":"8119","bank":"alinma"},{"ref":"alinma:8119:2:1","date":"2026-05-20","type":"refund","direction":"in","amount":100,"merchant":"X","norm":"x","category":null,"card":"8119","bank":"alinma"},{"ref":"alinma:8119:3:1","date":"2026-05-21","type":"wallet_topup","direction":"out","amount":500,"merchant":"barq","norm":"barq","category":"Transfers","card":"8119","bank":"alinma"},{"ref":"bad","date":"2026-05-20","type":"transfer_out","direction":"out","amount":100,"merchant":"X","norm":"x","category":null,"card":null,"bank":null}]'::jsonb);
  if n <> 3 then raise exception 'import inserted %, expected 3', n; end if;
  select count(*) into n from public.transactions where user_id = a and external_ref = 'alinma:8119:3:1' and is_internal and excluded_from_spend;
  if n <> 1 then raise exception 'wallet top-up import is not internal'; end if;
  n := public.import_statement_rows(a, '[{"ref":"alinma:8119:1:1","date":"2026-05-19","type":"purchase","direction":"out","amount":2740,"merchant":"LULU","norm":"lulu","category":"Groceries","card":"8119","bank":"alinma"}]'::jsonb);
  if n <> 0 then raise exception 'second import inserted %', n; end if;
  select count(*) into n from public.transactions t join public.categories c on c.id = t.category_id
    where t.user_id = a and t.source = 'csv' and c.name = 'Groceries' and t.occurred_at = '2026-05-19 09:00:00+00';
  if n <> 1 then raise exception 'imported row has wrong category or time'; end if;
  delete from public.transactions where user_id = a and source = 'csv';

  -- atomic rotation: always exactly one active token, the old one is revoked
  perform public.rotate_ingest_token(a, 'hash-a2', 'iPhone');
  perform public.rotate_ingest_token(a, 'hash-a3', 'iPhone');
  select count(*) into n from public.ingest_tokens where user_id = a and revoked_at is null;
  if n <> 1 then raise exception 'expected 1 active token after rotation, got %', n; end if;
  select count(*) into n from public.ingest_tokens where user_id = a and token_hash = 'hash-a3' and revoked_at is null;
  if n <> 1 then raise exception 'newest token is not the active one'; end if;
  denied := false;
  begin insert into public.ingest_tokens (user_id, token_hash) values (a, 'second-active');
  exception when unique_violation then denied := true; end;
  if not denied then raise exception 'two active tokens were allowed'; end if;

  -- a second kind: the app token lives next to the shortcut token and rotates on its own
  perform public.rotate_ingest_token(a, 'hash-app1', 'App', 'app');
  perform public.rotate_ingest_token(a, 'hash-app2', 'App', 'app');
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'app' and revoked_at is null;
  if n <> 1 then raise exception 'expected 1 active app token, got %', n; end if;
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'shortcut' and revoked_at is null and token_hash = 'hash-a3';
  if n <> 1 then raise exception 'creating the app token touched the shortcut token'; end if;
  perform public.revoke_ingest_token(a, 'app');
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'app' and revoked_at is null;
  if n <> 0 then raise exception 'app token was not revoked'; end if;
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'shortcut' and revoked_at is null;
  if n <> 1 then raise exception 'revoking the app token revoked the shortcut token'; end if;
  denied := false;
  begin perform public.rotate_ingest_token(a, 'hash-bad', 'x', 'admin'); exception when others then denied := true; end;
  if not denied then raise exception 'unknown token kind was accepted'; end if;

  -- widget token kind: its own slot, rotates independently, and the summary applies the spend rules
  perform public.rotate_ingest_token(a, 'hash-w1', 'Widget', 'widget');
  perform public.rotate_ingest_token(a, 'hash-w2', 'Widget', 'widget');
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'widget' and revoked_at is null;
  if n <> 1 then raise exception 'widget token should have one active row, got %', n; end if;
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'shortcut' and revoked_at is null;
  if n <> 1 then raise exception 'rotating the widget token touched the shortcut token'; end if;
  perform public.revoke_ingest_token(a, 'widget');
  select count(*) into n from public.ingest_tokens where user_id = a and kind = 'widget' and revoked_at is null;
  if n <> 0 then raise exception 'widget token was not revoked'; end if;

  update public.settings set monthly_budget_halalas = 500000 where user_id = a;
  insert into public.transactions (user_id, direction, type, amount_halalas, occurred_at, is_internal, excluded_from_spend, deleted_at)
  values
    (a, 'out', 'purchase', 1000, now(), false, false, null),
    (a, 'in',  'refund',   200,  now(), false, false, null),
    (a, 'out', 'transfer_out', 5000, now(), true,  false, null),
    (a, 'out', 'purchase', 7000, now(), false, true,  null),
    (a, 'out', 'purchase', 9000, now(), false, false, now()),
    (a, 'out', 'purchase', 9999, now() - interval '40 days', false, false, null);
  insert into public.transactions (user_id, direction, type, amount_halalas, occurred_at, category_id)
    select a, 'out', 'purchase', 3000, now(), c.id from public.categories c
    where c.user_id = a and c.excluded_from_spend limit 1;
  select count(*) into n from public.categories where user_id = a and excluded_from_spend;
  if n = 0 then raise exception 'seed has no excluded category: the excluded-category check below would prove nothing'; end if;
  -- earlier this month but not today (skipped on the 1st of the Riyadh month, where it would be today)
  if (now() at time zone 'Asia/Riyadh')::date > date_trunc('month', now() at time zone 'Asia/Riyadh')::date then
    insert into public.transactions (user_id, direction, type, amount_halalas, occurred_at)
    values (a, 'out', 'purchase', 400,
      (date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh') - interval '1 second');
    select count(*) into n from public.widget_summary(a) w
      where w.today_halalas = 800 and w.month_halalas = 1200 and w.budget_halalas = 500000;
  else
    select count(*) into n from public.widget_summary(a) w
      where w.today_halalas = 800 and w.month_halalas = 800 and w.budget_halalas = 500000;
  end if;
  if n <> 1 then raise exception 'widget_summary returned the wrong numbers'; end if;
  select count(*) into n from public.widget_summary(b) w where w.today_halalas = 0 and w.month_halalas = 0;
  if n <> 1 then raise exception 'widget_summary leaked another user''s rows or is not zero for an empty user'; end if;
  denied := false;
  begin perform public.rotate_ingest_token(a, 'hash-bad2', 'x', 'admin'); exception when others then denied := true; end;
  if not denied then raise exception 'unknown token kind was accepted (widget migration)'; end if;

  -- rate limiter counts per window and rejects unknown windows
  if public.bump_rate_limit(a, 'ingest_min', 'minute') <> 1 then raise exception 'first bump should be 1'; end if;
  if public.bump_rate_limit(a, 'ingest_min', 'minute') <> 2 then raise exception 'second bump should be 2'; end if;
  if public.bump_rate_limit(a, 'ingest_day', 'day') <> 1 then raise exception 'day bucket is separate'; end if;
  denied := false;
  begin perform public.bump_rate_limit(a, 'x', 'week'); exception when others then denied := true; end;
  if not denied then raise exception 'bad window accepted'; end if;
  insert into public.rate_limits (user_id, bucket, window_start, count) values (a, 'old', now() - interval '3 days', 5);
  perform public.bump_rate_limit(b, 'ingest_min', 'minute');
  select count(*) into n from public.rate_limits where bucket = 'old';
  if n <> 0 then raise exception 'old rate limit windows were not purged'; end if;

  -- account deletion grace period: marking, cancelling by signing in, and the purge after 30 days
  insert into auth.users (id, aud, role, email) values (g, 'authenticated', 'authenticated', 'rls-grace@example.test');
  insert into public.ingest_tokens (user_id, token_hash) values (g, 'hash-g-grace');
  insert into auth.sessions (user_id) values (g);
  perform public.request_account_deletion(g);
  select count(*) into n from public.ingest_tokens where user_id = g and revoked_at is null;
  if n <> 0 then raise exception 'deletion request left a live capture token'; end if;
  select count(*) into n from auth.sessions where user_id = g;
  if n <> 0 then raise exception 'deletion request left sessions open'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', a)::text, true);
  set local role authenticated;
  select count(*) into n from public.account_deletions;
  if n <> 0 then raise exception 'A can see another user''s pending deletion'; end if;
  denied := false;
  begin insert into public.account_deletions (user_id) values (a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'a client can mark its own account for deletion directly'; end if;
  denied := false;
  begin perform public.request_account_deletion(a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'a client can call request_account_deletion'; end if;
  if public.reactivate_my_account() then raise exception 'reactivate reported a cancel for an account that was not pending'; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', g)::text, true);
  set local role authenticated;
  if not public.reactivate_my_account() then raise exception 'reactivate did not cancel a pending deletion'; end if;
  if public.reactivate_my_account() then raise exception 'reactivate cancelled twice'; end if;
  reset role;
  perform public.request_account_deletion(g);
  update public.account_deletions set requested_at = now() - interval '29 days' where user_id = g;
  if public.purge_deleted_accounts() <> 0 then raise exception 'purge removed an account inside the grace period'; end if;
  update public.account_deletions set requested_at = now() - interval '31 days' where user_id = g;
  if public.purge_deleted_accounts() <> 1 then raise exception 'purge did not remove the expired account'; end if;
  select count(*) into n from auth.users where id = g;
  if n <> 0 then raise exception 'expired account still exists'; end if;
  -- asking twice restarts the clock, and the sign-in of the password re-check in between does not save the account
  insert into auth.users (id, aud, role, email, last_sign_in_at)
    values ('00000000-0000-0000-0000-0000000000f4', 'authenticated', 'authenticated', 'rls-twice@example.test', null);
  perform public.request_account_deletion('00000000-0000-0000-0000-0000000000f4');
  update public.account_deletions set requested_at = now() - interval '40 days'
    where user_id = '00000000-0000-0000-0000-0000000000f4';
  update auth.users set last_sign_in_at = now() where id = '00000000-0000-0000-0000-0000000000f4';
  perform public.request_account_deletion('00000000-0000-0000-0000-0000000000f4');
  select count(*) into n from public.account_deletions
    where user_id = '00000000-0000-0000-0000-0000000000f4' and requested_at > now() - interval '1 minute';
  if n <> 1 then raise exception 'a second deletion request did not restart the clock'; end if;
  if public.purge_deleted_accounts() <> 0 then raise exception 'a re-requested account was purged at once'; end if;
  delete from auth.users where id = '00000000-0000-0000-0000-0000000000f4';
  -- an account that signed in after asking to be deleted is kept, and its stale request is cleared
  insert into auth.users (id, aud, role, email, last_sign_in_at)
    values (h, 'authenticated', 'authenticated', 'rls-back@example.test', now());
  insert into public.account_deletions (user_id, requested_at) values (h, now() - interval '40 days');
  update auth.users set last_sign_in_at = now() where id = h;
  if public.purge_deleted_accounts() <> 0 then raise exception 'purge deleted an account that signed in again'; end if;
  select count(*) into n from auth.users where id = h;
  if n <> 1 then raise exception 'a returning account was deleted'; end if;
  select count(*) into n from public.account_deletions where user_id = h;
  if n <> 0 then raise exception 'the stale deletion request was not cleared'; end if;
  delete from auth.users where id = h;
  select count(*) into n from public.transactions where user_id = g;
  if n <> 0 then raise exception 'expired account left rows behind'; end if;
  

  -- the AI chat can record its spend, and an unknown purpose is still refused
  insert into public.ai_usage (user_id, day, purpose, cost_halalas) values (a, current_date, 'chat', 1);
  denied := false;
  begin insert into public.ai_usage (user_id, day, purpose) values (a, current_date, 'nonsense'); exception when check_violation then denied := true; end;
  if not denied then raise exception 'ai_usage accepted an unknown purpose'; end if;

  -- every table in public must have RLS on (catches a future table that forgets it)
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if n <> 0 then raise exception '% public table(s) without RLS', n; end if;

  -- deleting an account removes every row of that user in every public table (account deletion relies on the cascade)
  insert into public.ingest_tokens (user_id, token_hash) values (f, 'hash-f');
  insert into public.raw_messages (user_id, sender, body, received_at, dedupe_hash) values (f, 'alinma', 'body-f', now(), 'h-f');
  insert into public.ai_usage (user_id, day, purpose) values (f, current_date, 'insights');
  insert into public.own_accounts (user_id, bank, last4, kind) values (f, 'snb', '1111', 'account');
  perform public.bump_rate_limit(f, 'ingest_min', 'minute');
  select coalesce(sum(cost_halalas), 0) into n from public.ai_usage where created_at >= date_trunc('month', now());
  delete from auth.users where id = f;
  declare
    t record;
    c int;
    total int := 0;
    after_total bigint;
  begin
    -- the AI spend ledger survives, anonymously, so deleting an account cannot reset the shared budget
    select count(*) into c from public.ai_usage where user_id is null and purpose = 'insights';
    if c < 1 then raise exception 'account deletion removed the AI spend ledger'; end if;
    select total_halalas into after_total from public.ai_spend_summary(a, date_trunc('month', now()));
    if after_total < n then raise exception 'AI total dropped after an account was deleted'; end if;
    for t in
      select table_name from information_schema.columns
      where table_schema = 'public' and column_name = 'user_id' and table_name <> 'ai_usage'
    loop
      execute format('select count(*) from public.%I where user_id = $1', t.table_name) into c using f;
      if c <> 0 then raise exception 'account deletion left % rows in %', c, t.table_name; end if;
      total := total + 1;
    end loop;
    if total < 11 then raise exception 'cascade check looked at only % tables', total; end if;
  end;

  raise exception 'RLS_TESTS_OK';
end $$;

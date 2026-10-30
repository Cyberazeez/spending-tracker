-- RLS isolation test. Runs in one transaction and always rolls back (it raises at the end).
-- Success is the error message 'RLS_TESTS_OK'. Any other error message is a failed assertion.
-- Run: supabase db query < this file  (or the Supabase SQL editor / MCP execute_sql)

do $$
declare
  a uuid := '00000000-0000-0000-0000-00000000000a';
  b uuid := '00000000-0000-0000-0000-00000000000b';
  n int;
  denied boolean;
begin
  insert into auth.users (id, aud, role, email) values
    (a, 'authenticated', 'authenticated', 'rls-a@example.test'),
    (b, 'authenticated', 'authenticated', 'rls-b@example.test');

  -- trigger seeded both users
  select count(*) into n from public.categories where user_id in (a, b);
  if n <> 34 then raise exception 'seed: expected 34 categories, got %', n; end if;
  select count(*) into n from public.own_accounts where user_id = a;
  if n <> 17 then raise exception 'seed: expected 17 own_accounts for A, got %', n; end if;

  insert into public.ingest_tokens (user_id, token_hash) values (a, 'hash-a'), (b, 'hash-b');
  insert into public.raw_messages (user_id, sender, body, received_at, dedupe_hash)
    values (a, 'alinma', 'body-a', now(), 'h-a'), (b, 'alinma', 'body-b', now(), 'h-b');
  insert into public.ai_usage (user_id, day, purpose) values (a, current_date, 'parse');

  -- act as user A
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from public.categories;
  if n <> 17 then raise exception 'A sees % categories, expected 17', n; end if;
  select count(*) into n from public.raw_messages;
  if n <> 1 then raise exception 'A sees % raw_messages, expected 1', n; end if;
  select count(*) into n from public.settings;
  if n <> 1 then raise exception 'A sees % settings rows, expected 1', n; end if;

  -- cannot insert a row for B
  denied := false;
  begin
    insert into public.budgets (user_id, category_id, monthly_limit_halalas)
      select b, id, 1000 from public.categories where user_id = b limit 1;
  exception when others then denied := true; end;
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
  begin perform public.bump_rate_limit(a, 'ingest'); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called bump_rate_limit'; end if;
  denied := false;
  begin perform public.seed_defaults(a); exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A called seed_defaults'; end if;

  -- anon sees nothing
  reset role;
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  denied := false;
  begin perform 1 from public.transactions; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'anon could read transactions'; end if;

  reset role;
  raise exception 'RLS_TESTS_OK';
end $$;

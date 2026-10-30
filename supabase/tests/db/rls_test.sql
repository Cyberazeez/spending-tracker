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

  -- anon sees nothing

  -- settings: preferences are editable, the AI cap and row lifecycle are not
  update public.settings set ai_enabled = true, locale = 'ar';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'A could not update own settings preferences'; end if;
  denied := false;
  begin update public.settings set ai_monthly_cap_halalas = 999999999; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'A raised their own AI cap'; end if;
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

  reset role;
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  denied := false;
  begin perform 1 from public.transactions; exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'anon could read transactions'; end if;

  reset role;
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

  -- every table in public must have RLS on (catches a future table that forgets it)
  select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if n <> 0 then raise exception '% public table(s) without RLS', n; end if;

  raise exception 'RLS_TESTS_OK';
end $$;

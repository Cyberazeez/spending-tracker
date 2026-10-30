-- Row level security: owner only. anon gets nothing.

revoke all on all tables in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;

-- Plain owner tables: full CRUD on own rows
do $$
declare t text;
begin
  foreach t in array array[
    'settings', 'own_accounts', 'categories', 'merchant_rules', 'transactions',
    'obligations', 'obligation_instances', 'budgets', 'insights', 'device_tokens'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for all to authenticated
         using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))',
      t || '_owner', t);
  end loop;
end $$;

-- raw_messages: owner can read, and may only change the review fields. Rows are created by the ingest function.
alter table public.raw_messages enable row level security;
create policy raw_messages_select on public.raw_messages for select to authenticated
  using (user_id = (select auth.uid()));
create policy raw_messages_update on public.raw_messages for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke insert, delete, update on public.raw_messages from authenticated;
grant update (parse_status, ignore_reason, transaction_id) on public.raw_messages to authenticated;

-- ingest_tokens: owner may list metadata, never the hash. Created and revoked by functions.
alter table public.ingest_tokens enable row level security;
create policy ingest_tokens_select on public.ingest_tokens for select to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.ingest_tokens from authenticated;
grant select (id, user_id, label, created_at, last_used_at, revoked_at) on public.ingest_tokens to authenticated;

-- Service-role only: RLS on, no policies, no grants
alter table public.ai_usage enable row level security;
alter table public.rate_limits enable row level security;
revoke all on public.ai_usage, public.rate_limits from authenticated;

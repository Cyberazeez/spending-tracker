-- Core schema. See docs/05-backend-schema.md. Money is bigint halalas, times are timestamptz (UTC).

create extension if not exists pg_trgm with schema extensions;

-- 1 row per user
create table public.settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  base_salary_halalas bigint not null default 1410000 check (base_salary_halalas >= 0),
  salary_account_last4 text[] not null default '{6000}',
  ai_enabled boolean not null default false,
  ai_monthly_cap_halalas bigint not null default 1900 check (ai_monthly_cap_halalas >= 0),
  locale text not null default 'en' check (locale in ('en', 'ar')),
  week_start smallint not null default 0 check (week_start between 0 and 6),
  timezone text not null default 'Asia/Riyadh',
  created_at timestamptz not null default now()
);

create table public.own_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  bank text not null check (bank in ('alrajhi', 'snb', 'alinma', 'barq', 'd360', 'stc')),
  last4 text not null check (last4 ~ '^[0-9]{4}$'),
  kind text not null check (kind in ('account', 'debit_card', 'credit_card', 'wallet')),
  label text,
  is_active boolean not null default true,
  is_house_card boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, bank, last4)
);

create table public.ingest_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label text not null default 'iPhone',
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  name_ar text,
  kind text not null default 'spend' check (kind in ('spend', 'income', 'transfer', 'fee')),
  excluded_from_spend boolean not null default false,
  icon text,
  color text,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create table public.merchant_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  pattern text not null,
  match_type text not null default 'contains' check (match_type in ('exact', 'contains', 'prefix')),
  category_id uuid not null references public.categories(id) on delete cascade,
  status text not null default 'confirmed' check (status in ('confirmed', 'auto_unconfirmed')),
  source text not null default 'user' check (source in ('user', 'ai', 'seed')),
  hit_count int not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, pattern, match_type)
);

create table public.raw_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sender text not null,
  body text not null,
  received_at timestamptz not null,
  dedupe_hash text not null,
  parse_status text not null default 'needs_review'
    check (parse_status in ('parsed', 'ai_parsed', 'low_confidence', 'needs_review', 'ignored', 'failed')),
  ignore_reason text,
  parser text,
  confidence real,
  transaction_id uuid,
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_hash)
);
create index raw_messages_gaps_idx on public.raw_messages (user_id, sender, received_at desc);
create index raw_messages_review_idx on public.raw_messages (user_id, parse_status) where parse_status in ('needs_review', 'low_confidence', 'failed');

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  raw_message_id uuid references public.raw_messages(id) on delete set null,
  source text not null default 'manual' check (source in ('sms', 'manual', 'csv', 'ai')),
  bank text,
  account_last4 text,
  direction text not null check (direction in ('in', 'out')),
  type text not null check (type in (
    'purchase', 'refund', 'atm_withdrawal', 'transfer_out', 'transfer_in', 'salary',
    'bill_payment', 'card_payment', 'wallet_topup', 'loan_installment', 'fee')),
  amount_halalas bigint not null check (amount_halalas >= 0),
  orig_amount_minor bigint,
  orig_currency text,
  fx_rate numeric,
  amount_estimated boolean not null default false,
  merchant_raw text,
  merchant_norm text,
  counterparty_name text,
  counterparty_last4 text,
  category_id uuid references public.categories(id) on delete set null,
  category_source text check (category_source in ('rule', 'ai', 'manual')),
  rule_id uuid references public.merchant_rules(id) on delete set null,
  is_internal boolean not null default false,
  excluded_from_spend boolean not null default false,
  occurred_at timestamptz not null,
  note text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
create index transactions_user_time_idx on public.transactions (user_id, occurred_at desc) where deleted_at is null;
create index transactions_user_cat_idx on public.transactions (user_id, category_id, occurred_at) where deleted_at is null;
create index transactions_merchant_trgm_idx on public.transactions using gin (merchant_norm extensions.gin_trgm_ops);

alter table public.raw_messages
  add constraint raw_messages_transaction_fk
  foreign key (transaction_id) references public.transactions(id) on delete set null;

create table public.obligations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  category_id uuid references public.categories(id) on delete set null,
  kind text not null check (kind in ('bill', 'fixed', 'loan', 'card_statement')),
  amount_type text not null check (amount_type in ('fixed', 'estimated')),
  expected_amount_halalas bigint check (expected_amount_halalas >= 0),
  frequency text not null default 'monthly' check (frequency in ('monthly', 'quarterly', 'annual', 'custom')),
  due_rule jsonb not null default '{}'::jsonb,
  lead_days int not null default 2 check (lead_days >= 0),
  match jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.obligation_instances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  obligation_id uuid not null references public.obligations(id) on delete cascade,
  period_start date not null,
  due_date date not null,
  expected_amount_halalas bigint check (expected_amount_halalas >= 0),
  actual_amount_halalas bigint check (actual_amount_halalas >= 0),
  status text not null default 'pending' check (status in ('pending', 'paid', 'overdue', 'skipped')),
  paid_at timestamptz,
  transaction_id uuid references public.transactions(id) on delete set null,
  source_raw_message_id uuid references public.raw_messages(id) on delete set null,
  match_state text not null default 'none' check (match_state in ('auto', 'suggested', 'manual', 'none')),
  created_at timestamptz not null default now(),
  unique (obligation_id, period_start)
);
create index obligation_instances_due_idx on public.obligation_instances (user_id, status, due_date);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  monthly_limit_halalas bigint not null check (monthly_limit_halalas > 0),
  created_at timestamptz not null default now(),
  unique (user_id, category_id)
);

create table public.insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  kind text not null check (kind in ('weekly', 'on_demand')),
  metrics jsonb not null default '{}'::jsonb,
  tips jsonb not null default '[]'::jsonb,
  model text,
  created_at timestamptz not null default now()
);
create unique index insights_weekly_uidx on public.insights (user_id, kind, period_start) where kind = 'weekly';

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  apns_token text not null,
  environment text not null check (environment in ('sandbox', 'prod')),
  created_at timestamptz not null default now(),
  unique (user_id, apns_token)
);

-- Service-role only tables
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  purpose text not null check (purpose in ('parse', 'categorize', 'insights')),
  input_tokens int not null default 0,
  output_tokens int not null default 0,
  cost_halalas bigint not null default 0,
  created_at timestamptz not null default now()
);
create index ai_usage_user_day_idx on public.ai_usage (user_id, day);

create table public.rate_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket text not null,
  window_start timestamptz not null,
  count int not null default 0,
  primary key (user_id, bucket, window_start)
);

-- Atomic per-minute counter used by the ingest function. Returns the new count.
create or replace function public.bump_rate_limit(p_user uuid, p_bucket text)
returns int
language sql
security definer
set search_path = public
as $$
  insert into public.rate_limits as r (user_id, bucket, window_start, count)
  values (p_user, p_bucket, date_trunc('minute', now()), 1)
  on conflict (user_id, bucket, window_start) do update set count = r.count + 1
  returning count;
$$;
revoke execute on function public.bump_rate_limit(uuid, text) from public, anon, authenticated;
grant execute on function public.bump_rate_limit(uuid, text) to service_role;

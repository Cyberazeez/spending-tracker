-- Row quotas and length caps on the tables a signed-in user can write directly through the API.
-- Before this, one account could insert unlimited rows or megabyte-long strings (storage cost, slow dashboards).
-- Quotas apply only to requests made as a signed-in user (auth.uid() is set); the ingest function and other
-- service-role code are not limited here, they have their own rate limits.

create or replace function public.enforce_row_quota() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int := tg_argv[0]::int;
  v_n int;
begin
  if auth.uid() is null then return new; end if;  -- service role / internal jobs
  execute format(
    'select count(*) from (select 1 from public.%I where user_id = $1 limit %s) s', tg_table_name, v_limit + 1
  ) into v_n using new.user_id;
  if v_n >= v_limit then
    raise exception 'row_quota_exceeded: % (limit %)', tg_table_name, v_limit using errcode = '54000';
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_row_quota() from public, anon, authenticated;

create trigger own_accounts_quota before insert on public.own_accounts
  for each row execute function public.enforce_row_quota(50);
create trigger categories_quota before insert on public.categories
  for each row execute function public.enforce_row_quota(200);
create trigger merchant_rules_quota before insert on public.merchant_rules
  for each row execute function public.enforce_row_quota(5000);
create trigger budgets_quota before insert on public.budgets
  for each row execute function public.enforce_row_quota(200);
create trigger obligations_quota before insert on public.obligations
  for each row execute function public.enforce_row_quota(100);
create trigger device_tokens_quota before insert on public.device_tokens
  for each row execute function public.enforce_row_quota(20);
-- No quota on transactions: signed-in inserts are manual entries only (ingest and statement import run as service
-- role), the count could not use the partial indexes, and the quota caps abuse nobody can reach through the app.

-- Length caps. NOT VALID: they apply to every new or changed row without rescanning old ones.
-- Only fields the user types are capped; text copied from a bank SMS (merchant_raw, counterparty) is not, so ingest
-- can never fail on a long message.
alter table public.categories
  add constraint categories_text_len check (
    char_length(name) between 1 and 60 and char_length(coalesce(name_ar, '')) <= 60
    and char_length(coalesce(icon, '')) <= 40 and char_length(coalesce(color, '')) <= 20) not valid;
alter table public.merchant_rules
  add constraint merchant_rules_pattern_len check (char_length(pattern) between 1 and 200) not valid;
alter table public.own_accounts
  add constraint own_accounts_label_len check (char_length(coalesce(label, '')) <= 60) not valid;
alter table public.transactions
  add constraint transactions_note_len check (char_length(coalesce(note, '')) <= 500) not valid;
alter table public.obligations
  add constraint obligations_text_len check (
    char_length(name) between 1 and 80
    and octet_length(due_rule::text) <= 2000 and octet_length(match::text) <= 2000) not valid;

-- Bank statement import: history rows come from a statement PDF, not an SMS.
-- external_ref makes the import idempotent: importing the same statement twice changes nothing.

alter table public.transactions add column if not exists external_ref text;
create unique index if not exists transactions_external_ref_uidx
  on public.transactions (user_id, external_ref) where external_ref is not null;

-- Service-role only. p_rows is a JSON array of
-- { ref, date (YYYY-MM-DD), type (purchase|refund|fee|wallet_topup), direction (in|out), amount (halalas),
--   merchant, norm, category (a category name or null), card, bank }.
-- The date is stored at 12:00 Riyadh because statements carry no time. Rows already imported are skipped.
create or replace function public.import_statement_rows(p_user uuid, p_rows jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'rows must be an array';
  end if;
  with src as (
    select r.* from jsonb_to_recordset(p_rows) as r(
      ref text, date date, type text, direction text, amount bigint,
      merchant text, norm text, category text, card text, bank text)
  ), ins as (
    insert into public.transactions
      (user_id, source, bank, card_last4, direction, type, amount_halalas, merchant_raw, merchant_norm,
       category_id, category_source, is_internal, excluded_from_spend, occurred_at, external_ref)
    select p_user, 'csv', coalesce(s.bank, 'alinma'), s.card, s.direction, s.type, s.amount, s.merchant, s.norm,
           c.id, case when c.id is null then null else 'rule' end, s.type = 'wallet_topup', s.type = 'wallet_topup',
           ((s.date + time '12:00') at time zone 'Asia/Riyadh'), s.ref
    from src s
    left join public.categories c on c.user_id = p_user and c.name = s.category
    where s.ref is not null and s.amount >= 0 and s.type in ('purchase', 'refund', 'fee', 'wallet_topup')
      and s.direction in ('in', 'out')
    on conflict (user_id, external_ref) where external_ref is not null do nothing
    returning 1
  )
  select count(*) into n from ins;
  return n;
end;
$$;
revoke execute on function public.import_statement_rows(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.import_statement_rows(uuid, jsonb) to service_role;

-- One-time pass (owner decision 2026-11-08): pair transfers already in the database with the same strict rule that
-- ingest now uses. Not a migration: run the PREVIEW first, look at it, then the APPLY block if it looks right.
--   out and in, same amount, within 5 minutes, not deleted, not already internal,
--   another bank, or the same bank with two known different account digits,
--   digits (when both messages show them) must not contradict, each row in at most one pair (nearest wins).
-- The preview shows only the banks and the gap: no names, no merchants, no digits.

drop table if exists _pairs;
create temporary table _pairs as
with o as (
  select * from public.transactions
  where type = 'transfer_out' and deleted_at is null and not is_internal
), i as (
  select * from public.transactions
  where type = 'transfer_in' and deleted_at is null and not is_internal
), cand as (
  select o.user_id, o.id as out_id, i.id as in_id,
         o.bank as out_bank, i.bank as in_bank,
         o.account_last4 as out_acct, o.counterparty_last4 as out_other,
         i.account_last4 as in_acct, i.counterparty_last4 as in_other,
         abs(extract(epoch from (o.occurred_at - i.occurred_at))) as gap_s
  from o join i
    on i.user_id = o.user_id and i.amount_halalas = o.amount_halalas
   and abs(extract(epoch from (o.occurred_at - i.occurred_at))) <= 300
), ok as (
  select * from cand
  where (out_bank <> in_bank or (out_acct is not null and in_acct is not null and out_acct <> in_acct))
    and not (out_other is not null and in_acct is not null and out_other <> in_acct)
    and not (in_other is not null and out_acct is not null and in_other <> out_acct)
), ranked as (
  select *,
         row_number() over (partition by out_id order by gap_s, in_id) as r_out,
         row_number() over (partition by in_id order by gap_s, out_id) as r_in
  from ok
)
select * from ranked where r_out = 1 and r_in = 1;

-- PREVIEW: how many pairs, and each one without any personal detail
select count(*) as pairs, count(distinct user_id) as users from _pairs;
select out_bank, in_bank, round(gap_s / 60.0, 1) as gap_min from _pairs order by gap_s;

-- APPLY (run only after the preview was approved): flag both rows, file them under Transfers when they have no
-- category, and save the accounts of each pair as the user's own (skipping any last 4 already saved).
-- update public.transactions t set is_internal = true, excluded_from_spend = true,
--   category_id = coalesce(t.category_id, (select c.id from public.categories c where c.user_id = t.user_id and c.name = 'Transfers')),
--   category_source = case when t.category_id is null then 'rule' else t.category_source end
-- where t.id in (select out_id from _pairs union select in_id from _pairs);
--
-- insert into public.own_accounts (user_id, bank, last4, kind)
-- select distinct on (user_id, last4) user_id, bank, last4, 'account' from (
--   select user_id, out_bank as bank, coalesce(out_acct, in_other) as last4 from _pairs
--   union all
--   select user_id, in_bank, coalesce(in_acct, out_other) from _pairs
-- ) a
-- where last4 ~ '^[0-9]{4}$' and bank in ('alrajhi','snb','alinma','barq','d360','stc')
--   and not exists (select 1 from public.own_accounts x where x.user_id = a.user_id and x.last4 = a.last4)
-- order by user_id, last4;

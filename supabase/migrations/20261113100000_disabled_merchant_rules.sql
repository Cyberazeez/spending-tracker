-- Owner decision 2026-11-13: a merchant rule deleted on More > Categories and rules stays deleted. The app marks it
-- 'disabled' instead of removing the row, so nothing re-creates it:
--   - seed backfills insert with "on conflict do nothing" and leave the row as it is;
--   - categorize-batch skips merchants that already have a rule (any status) and upserts with ignoreDuplicates;
--   - ingest skips disabled rules when it categorises a message.
-- Choosing "always file this place under ..." again in the app sets the rule back to 'confirmed'.
alter table public.merchant_rules drop constraint if exists merchant_rules_status_check;
alter table public.merchant_rules add constraint merchant_rules_status_check
  check (status in ('confirmed', 'auto_unconfirmed', 'disabled'));

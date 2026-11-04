-- Deleting an account must not reset the shared AI budget (review of stage C, 2026-11-04):
-- the spend rows stay as an anonymous ledger (user_id becomes null) and keep counting in the all-users total.
alter table public.ai_usage alter column user_id drop not null;
alter table public.ai_usage drop constraint if exists ai_usage_user_id_fkey;
alter table public.ai_usage
  add constraint ai_usage_user_id_fkey foreign key (user_id) references auth.users(id) on delete set null;

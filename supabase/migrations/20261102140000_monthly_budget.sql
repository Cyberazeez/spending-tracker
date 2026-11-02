-- One overall monthly spending limit (used by the home-screen widget's budget percentage).
-- Null means not set. Category budgets (table budgets) are separate and unchanged.
alter table public.settings
  add column monthly_budget_halalas bigint
  check (monthly_budget_halalas is null or (monthly_budget_halalas > 0 and monthly_budget_halalas <= 10000000000));
grant update (monthly_budget_halalas) on public.settings to authenticated;

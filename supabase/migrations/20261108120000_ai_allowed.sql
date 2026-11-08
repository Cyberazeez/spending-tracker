-- AI is for paying customers only (owner decision 2026-11-05). `ai_allowed` is the server-side switch the purchase
-- flow will flip; the app cannot write it (settings has column-level UPDATE grants, and this column is not in them).
alter table public.settings add column ai_allowed boolean not null default false;

-- Every account that exists today (the owner and the family testers) keeps AI (owner decision 2026-11-08).
update public.settings set ai_allowed = true;

-- New accounts start with no AI budget; the server sets a quota when a plan starts. (The old default of 1,900
-- halalas was above the global ceiling of 1,875, so one user alone could exceed it.)
alter table public.settings alter column ai_monthly_cap_halalas set default 0;

comment on column public.settings.ai_allowed is
  'Paid-plan switch, server-side only. AI features need ai_allowed AND ai_enabled (the user''s own switch).';

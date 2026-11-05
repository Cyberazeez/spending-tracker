-- Record the bills' issue days in the repo (owner rule 2026-11-05: a bill issued on the 1st-19th belongs to that month,
-- the 20th or later to the next). Production already has these values (set by hand); this makes a rebuilt database match
-- it. Only bills that do not have an issue_day yet are touched, so re-running or an owner edit is never overwritten.
update public.obligations
set due_rule = due_rule || '{"issue_day": 27}'::jsonb
where name in ('Mobile (STC 0569)', 'Internet (STC 7356)') and kind = 'bill' and not (due_rule ? 'issue_day');

update public.obligations
set due_rule = due_rule || '{"issue_day": 6}'::jsonb
where name = 'Electricity (SEC)' and kind = 'bill' and not (due_rule ? 'issue_day');

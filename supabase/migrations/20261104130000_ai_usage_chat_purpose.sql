-- The AI chat (Insights > AI tips > Ask) records its spend under its own purpose.
alter table public.ai_usage drop constraint ai_usage_purpose_check;
alter table public.ai_usage
  add constraint ai_usage_purpose_check check (purpose in ('parse', 'categorize', 'insights', 'chat'));

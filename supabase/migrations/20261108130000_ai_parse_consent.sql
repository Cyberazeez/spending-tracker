-- The person's own consent for AI reading of bank messages the app has no parser for. Separate from the AI assistant
-- switch, because this one sends (redacted) message text to Anthropic; the assistant sends only totals and merchant
-- names. Off by default. Needs the paid flag (`ai_allowed`, server-side) as well.
alter table public.settings add column ai_parse_enabled boolean not null default false;
grant update (ai_parse_enabled) on public.settings to authenticated;

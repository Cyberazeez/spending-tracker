-- Two kinds of ingest token per user, so the app can hold its own token without revoking the owner's Shortcut token.
--   shortcut: the one shown in More > Ingest token and pasted into a user-built shortcut (unchanged behaviour)
--   app:      created by the app on sign-in and kept only in the iOS Keychain (used by the "Add bank message" action)
-- At most one active token per user per kind. `ingest` accepts either kind (it only looks the hash up).
alter table public.ingest_tokens
  add column kind text not null default 'shortcut' check (kind in ('shortcut', 'app'));

drop index public.ingest_tokens_one_active;
create unique index ingest_tokens_one_active_per_kind
  on public.ingest_tokens (user_id, kind) where revoked_at is null;

-- The owner may read the kind (never the hash).
grant select (kind) on public.ingest_tokens to authenticated;

-- Same atomic rotation, now per kind. The default keeps the 3-argument call of the deployed `rotate-token` working.
drop function public.rotate_ingest_token(uuid, text, text);
create function public.rotate_ingest_token(p_user uuid, p_hash text, p_label text, p_kind text default 'shortcut')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('shortcut', 'app') then
    raise exception 'bad token kind';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text || ':' || p_kind, 0));
  update public.ingest_tokens set revoked_at = now()
    where user_id = p_user and kind = p_kind and revoked_at is null;
  insert into public.ingest_tokens (user_id, label, token_hash, kind) values (p_user, p_label, p_hash, p_kind);
end;
$$;
revoke execute on function public.rotate_ingest_token(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.rotate_ingest_token(uuid, text, text, text) to service_role;

-- Revokes the active token of one kind (the app does this on sign-out).
create function public.revoke_ingest_token(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('shortcut', 'app') then
    raise exception 'bad token kind';
  end if;
  update public.ingest_tokens set revoked_at = now()
    where user_id = p_user and kind = p_kind and revoked_at is null;
end;
$$;
revoke execute on function public.revoke_ingest_token(uuid, text) from public, anon, authenticated;
grant execute on function public.revoke_ingest_token(uuid, text) to service_role;

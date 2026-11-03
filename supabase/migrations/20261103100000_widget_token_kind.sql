-- Third ingest-token kind for the self-refreshing home-screen widget (roadmap item 4).
--   widget: created by the app, stored in the shared App Group so the widget extension can read it, and good for
--           ONE thing: calling `widget-summary`, which returns three numbers (today, month, budget).
--           It can never post messages: `ingest` only accepts kinds 'shortcut' and 'app'.
alter table public.ingest_tokens drop constraint ingest_tokens_kind_check;
alter table public.ingest_tokens
  add constraint ingest_tokens_kind_check check (kind in ('shortcut', 'app', 'widget'));

create or replace function public.rotate_ingest_token(p_user uuid, p_hash text, p_label text, p_kind text default 'shortcut')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('shortcut', 'app', 'widget') then
    raise exception 'bad token kind';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text || ':' || p_kind, 0));
  update public.ingest_tokens set revoked_at = now()
    where user_id = p_user and kind = p_kind and revoked_at is null;
  insert into public.ingest_tokens (user_id, label, token_hash, kind) values (p_user, p_label, p_hash, p_kind);
end;
$$;

create or replace function public.revoke_ingest_token(p_user uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind not in ('shortcut', 'app', 'widget') then
    raise exception 'bad token kind';
  end if;
  update public.ingest_tokens set revoked_at = now()
    where user_id = p_user and kind = p_kind and revoked_at is null;
end;
$$;

-- The three widget numbers, in Riyadh time (UTC+3, no DST). Same rule as the app's month total: outgoing money that
-- is not internal, not flagged and not in an excluded category (Transfers, Income), minus refunds; deleted rows out.
create or replace function public.widget_summary(p_user uuid)
returns table (today_halalas bigint, month_halalas bigint, budget_halalas bigint)
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select (date_trunc('day', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh') as day_start,
           (date_trunc('month', now() at time zone 'Asia/Riyadh') at time zone 'Asia/Riyadh') as month_start
  ), spend as (
    select t.occurred_at,
           case when t.direction = 'out' then t.amount_halalas
                when t.type = 'refund' then -t.amount_halalas
                else 0 end as amt
    from public.transactions t
    left join public.categories c on c.id = t.category_id
    where t.user_id = p_user
      and t.deleted_at is null
      and not t.is_internal
      and not t.excluded_from_spend
      and coalesce(c.excluded_from_spend, false) = false
      and t.occurred_at >= (select month_start from bounds)
  )
  select coalesce(sum(amt) filter (where occurred_at >= (select day_start from bounds)), 0)::bigint,
         coalesce(sum(amt), 0)::bigint,
         (select s.monthly_budget_halalas from public.settings s where s.user_id = p_user)
  from spend;
$$;
revoke execute on function public.widget_summary(uuid) from public, anon, authenticated;
grant execute on function public.widget_summary(uuid) to service_role;

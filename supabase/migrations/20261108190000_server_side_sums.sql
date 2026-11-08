-- Two numbers the app used to add up on the phone from at most 500 / 1000 fetched rows (rows beyond that were
-- silently left out). Both run with the caller's rights (security invoker), so RLS keeps them to the caller's rows.

-- Last message per sender (the "possible gaps" view), oldest first.
create or replace function public.my_sender_gaps()
returns table (sender text, last_received_at timestamptz)
language sql
stable
set search_path = public
as $$
  select m.sender, max(m.received_at)
  from public.raw_messages m
  group by m.sender
  order by max(m.received_at);
$$;
revoke execute on function public.my_sender_gaps() from public, anon;
grant execute on function public.my_sender_gaps() to authenticated;

-- Spending since p_start by the same rule as the Insights month total and the widget server: outgoing money that is
-- not internal, flagged or in an excluded category (Transfers, Income), minus refunds.
create or replace function public.my_spend_since(p_start timestamptz)
returns bigint
language sql
stable
set search_path = public
as $$
  select coalesce(sum(case
           when t.direction = 'out' then t.amount_halalas
           when t.type = 'refund' then -t.amount_halalas
           else 0
         end), 0)::bigint
  from public.transactions t
  left join public.categories c on c.id = t.category_id
  where not t.is_internal
    and not t.excluded_from_spend
    and t.deleted_at is null
    and t.occurred_at >= p_start
    and coalesce(c.excluded_from_spend, false) = false;
$$;
revoke execute on function public.my_spend_since(timestamptz) from public, anon;
grant execute on function public.my_spend_since(timestamptz) to authenticated;

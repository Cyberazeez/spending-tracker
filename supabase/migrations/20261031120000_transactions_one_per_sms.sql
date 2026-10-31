-- One SMS yields at most one transaction of each type (the transfer itself, and its fee).
-- NULL raw_message_id (manual rows) is never considered equal, so manual entries are unaffected.
create unique index transactions_raw_type_uidx on public.transactions (raw_message_id, type);

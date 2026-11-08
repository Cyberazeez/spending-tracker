-- Direct writes to obligations bypassed the validation in save_my_obligation / stop_my_obligation (day ranges,
-- match words, kind, amounts). The app only reads this table directly and writes through those security-definer
-- functions, so signed-in users keep read access only.
revoke insert, update, delete on public.obligations from authenticated;
grant select on public.obligations to authenticated;

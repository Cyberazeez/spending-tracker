-- Own accounts can now be at any SAMA-licensed local or digital bank, plus the wallets the owner uses.
-- Existing rows (alrajhi, snb, alinma, barq, d360, stc) stay valid. The SMS parsers still only know the original six.
alter table public.own_accounts drop constraint if exists own_accounts_bank_check;
alter table public.own_accounts add constraint own_accounts_bank_check check (bank in (
  'snb', 'alrajhi', 'riyad', 'sab', 'anb', 'alinma', 'bsf', 'saib', 'aljazira', 'albilad', 'gib',
  'stc', 'vision', 'd360',
  'barq', 'urpay', 'mobilypay', 'alinmapay'
));

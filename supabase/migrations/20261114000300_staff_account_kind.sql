-- Separate transaction: PostgreSQL enum additions must commit before use.
begin;
alter type public.account_kind add value if not exists 'staff';
commit;

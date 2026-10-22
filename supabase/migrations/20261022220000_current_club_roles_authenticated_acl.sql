-- Allow authenticated sessions to evaluate their own club roles.
-- The function is SECURITY DEFINER and derives identity only from auth.uid(),
-- so callers cannot request another user's roles.
begin;
grant usage on schema private to authenticated;
grant execute on function private.current_club_roles() to authenticated;
revoke execute on function private.current_club_roles() from anon, public;
commit;

-- The platform-admin predicate is intentionally used by RLS policies
-- across several protected tables and Storage buckets. PostgreSQL may evaluate
-- policy expressions before narrowing rows by bucket, so authenticated requests
-- can otherwise fail with "permission denied for function is_active_platform_admin".
-- The helper returns only a boolean and remains SECURITY DEFINER; do not grant anon.
begin;
grant usage on schema private to authenticated;
grant execute on function private.is_active_platform_admin(uuid) to authenticated;
revoke execute on function private.is_active_platform_admin(uuid) from anon, public;
commit;

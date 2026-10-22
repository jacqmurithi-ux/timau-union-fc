-- RLS policies call this helper for platform-admin access.
grant execute on function private.is_active_platform_admin(uuid) to authenticated;

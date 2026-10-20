-- Timau Union FC — rollback for 20261020170000_platform_access_workflow.sql
-- DRAFT ONLY. Destructive: this drops all access request, role and audit data created
-- after the migration. Export/audit-retention requirements must be considered first.
-- Do not run without explicit owner approval and a fresh verified backup.

begin;

drop trigger if exists timau_auth_user_pending_access on auth.users;

drop function if exists public.admin_get_audit_events(integer);
drop function if exists public.admin_assign_club_role(uuid, text, text);
drop function if exists public.admin_set_account_status(uuid, text, text);
drop function if exists public.admin_list_access_requests();
drop function if exists public.get_my_access_status();

drop function if exists private.on_auth_user_created();
drop function if exists private.is_active_platform_admin(uuid);
drop function if exists private.touch_updated_at();

drop table if exists private.audit_events;
drop table if exists private.role_assignments;
drop table if exists private.platform_admins;
drop table if exists private.account_access;
drop table if exists private.user_profiles;

-- Only drop the schema if empty. Never cascade over objects not owned by this migration.
drop schema if exists private;

commit;

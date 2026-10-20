-- Manual rollback only. DESTRUCTIVE: permanently deletes all workspace records and audit history.
-- Run only after confirming this migration was applied to the intended non-production project
-- and after exporting any data that must be retained. This script does not roll back the
-- environment-specific private.current_club_roles() adapter; review that adapter separately.
begin;
drop function if exists public.get_published_club_content();
drop function if exists public.club_set_publication_status(uuid,text,text);
drop function if exists public.club_save_record(uuid,text,jsonb);
drop function if exists public.club_get_workspace_bundle();
drop function if exists private.valid_club_record_data(text,jsonb);
drop function if exists private.role_can_manage_record(text[],text);
drop table if exists private.club_record_audit;
drop table if exists private.club_records;
commit;

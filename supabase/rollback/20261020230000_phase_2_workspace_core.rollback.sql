-- Manual rollback only; permanently deletes workspace data and audit history.
begin;
drop function if exists public.get_published_club_content();
drop function if exists public.club_set_publication_status(uuid,text,text);
drop function if exists public.club_save_record(uuid,text,jsonb);
drop function if exists public.club_get_workspace_bundle();
drop function if exists private.role_can_manage_record(text[],text);
drop table if exists private.club_record_audit;
drop table if exists private.club_records;
commit;

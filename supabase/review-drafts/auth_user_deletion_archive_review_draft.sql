-- Phase 1 Auth-user deletion archival — REVIEW DRAFT ONLY.
-- Apply only after identity_roles_review_draft.sql and transactional_identity_workflows_review_draft.sql.
-- Union Test only after review. Never apply to production without separate explicit approval.
begin;

-- Preserve membership and role history when an Auth account is deleted.
alter table public.club_memberships alter column user_id drop not null;
alter table public.club_memberships drop constraint club_memberships_user_id_fkey;
alter table public.club_memberships add constraint club_memberships_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

-- System-driven deletion revocation has no surviving human actor ID.
alter table public.role_assignments drop constraint role_revocation_consistent;
alter table public.role_assignments add constraint role_revocation_consistent check (
  (revoked_at is null and revoked_by is null) or revoked_at is not null
);

-- Retain invitation history when the requesting account is deleted.
alter table public.invitation_requests alter column requested_by drop not null;
alter table public.invitation_requests drop constraint invitation_requests_requested_by_fkey;
alter table public.invitation_requests add constraint invitation_requests_requested_by_fkey
  foreign key (requested_by) references auth.users(id) on delete set null;

create or replace function private.archive_deleted_auth_user_membership()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_membership_id uuid;
  v_previous_status text;
  v_roles_revoked integer := 0;
begin
  select m.id, m.status into v_membership_id, v_previous_status
  from public.club_memberships m
  where m.user_id = old.id
  for update;

  if v_membership_id is not null then
    update public.role_assignments
      set revoked_at = coalesce(revoked_at, clock_timestamp()), revoked_by = null
      where membership_id = v_membership_id and revoked_at is null;
    get diagnostics v_roles_revoked = row_count;

    update public.club_memberships
      set user_id = null, status = 'revoked', revoked_at = coalesce(revoked_at, clock_timestamp())
      where id = v_membership_id;

    insert into public.audit_events(actor_user_id, action_key, entity_type, entity_id, outcome, details)
    values (null, 'auth_user_deleted', 'club_membership', v_membership_id::text, 'success',
      jsonb_build_object('previous_status', v_previous_status, 'roles_revoked', v_roles_revoked));
  end if;

  return old;
end;
$$;

revoke all on function private.archive_deleted_auth_user_membership() from public, anon, authenticated, service_role;
drop trigger if exists auth_user_archive_membership_before_delete on auth.users;
create trigger auth_user_archive_membership_before_delete
  before delete on auth.users
  for each row execute function private.archive_deleted_auth_user_membership();

commit;

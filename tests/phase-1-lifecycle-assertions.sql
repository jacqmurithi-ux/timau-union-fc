-- Phase 1 invitation lifecycle and Auth-user deletion assertions.
-- Run only against disposable Union Test after all review drafts have been applied.
-- Every fixture is inside a transaction and rolled back; no email is sent.
begin;
do $invitation_test$
declare
  v_chair uuid := '20000000-0000-4000-8000-000000000001';
  v_accept_user uuid := '20000000-0000-4000-8000-000000000002';
  v_expire_user uuid := '20000000-0000-4000-8000-000000000003';
  v_accept_request uuid := '20000000-0000-4000-8000-000000000011';
  v_cancel_request uuid := '20000000-0000-4000-8000-000000000012';
  v_expire_request uuid := '20000000-0000-4000-8000-000000000013';
  v_id uuid;
  v_claimed uuid;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values
    (v_chair,'authenticated','authenticated','phase1-chairman-lifecycle@example.invalid','',clock_timestamp(),'{}','{}',clock_timestamp(),clock_timestamp()),
    (v_accept_user,'authenticated','authenticated','phase1-accept-lifecycle@example.invalid','',clock_timestamp(),'{}','{}',clock_timestamp(),clock_timestamp()),
    (v_expire_user,'authenticated','authenticated','phase1-expire-lifecycle@example.invalid','',clock_timestamp(),'{}','{}',clock_timestamp(),clock_timestamp());
  insert into public.user_profiles(user_id,display_name) values(v_chair,'Test Chairman');
  insert into public.club_memberships(user_id,status,invited_email,activated_at)
  values(v_chair,'active','phase1-chairman-lifecycle@example.invalid',clock_timestamp());
  insert into public.role_assignments(membership_id,role_key,assigned_by)
  select id,'chairman',v_chair from public.club_memberships where user_id=v_chair;

  v_id := public.club_admin_begin_invitation(v_chair,'phase1-accept-lifecycle@example.invalid','secretary',v_accept_request);
  if public.club_admin_begin_invitation(v_chair,'phase1-accept-lifecycle@example.invalid','secretary',v_accept_request) <> v_id then
    raise exception 'FAIL: idempotent request did not return original invitation';
  end if;
  select id into v_claimed from public.club_admin_claim_invitation(v_id);
  if v_claimed is distinct from v_id then raise exception 'FAIL: invitation claim failed'; end if;
  if public.club_admin_record_invitation_auth_user(v_id,v_accept_user) <> 'recorded' then raise exception 'FAIL: Auth checkpoint failed'; end if;
  if public.club_admin_finish_invitation(v_id,true,v_accept_user,null) <> 'sent' then raise exception 'FAIL: invitation finalization failed'; end if;
  if public.club_admin_activate_invitation(v_accept_user,v_id) <> 'active' then raise exception 'FAIL: verified invite activation failed'; end if;
  if not exists(select 1 from public.club_memberships where user_id=v_accept_user and status='active') then raise exception 'FAIL: accepted membership not active'; end if;

  v_id := public.club_admin_begin_invitation(v_chair,'phase1-cancel-lifecycle@example.invalid','treasurer',v_cancel_request);
  select id into v_claimed from public.club_admin_claim_invitation(v_id);
  if v_claimed is distinct from v_id then raise exception 'FAIL: cancellation fixture claim failed'; end if;
  if public.club_admin_finish_invitation(v_id,false,null,'auth_invite_failed') <> 'failed' then raise exception 'FAIL: provider-failure transition failed'; end if;
  if public.club_admin_cancel_invitation(v_chair,v_id) <> 'cancelled' then raise exception 'FAIL: cancellation transition failed'; end if;
  if not exists(select 1 from public.invitation_requests where id=v_id and state='cancelled' and cancelled_at is not null) then raise exception 'FAIL: cancelled state not persisted'; end if;

  v_id := public.club_admin_begin_invitation(v_chair,'phase1-expire-lifecycle@example.invalid','coach',v_expire_request);
  select id into v_claimed from public.club_admin_claim_invitation(v_id);
  if v_claimed is distinct from v_id then raise exception 'FAIL: expiry fixture claim failed'; end if;
  perform public.club_admin_record_invitation_auth_user(v_id,v_expire_user);
  if public.club_admin_finish_invitation(v_id,true,v_expire_user,null) <> 'sent' then raise exception 'FAIL: expiry fixture finalization failed'; end if;
  update public.invitation_requests set created_at=clock_timestamp()-interval '8 days', expires_at=clock_timestamp()-interval '1 day' where id=v_id;
  if public.club_admin_activate_invitation(v_expire_user,v_id) <> 'expired' then raise exception 'FAIL: expired invitation was not rejected'; end if;
  if not exists(select 1 from public.invitation_requests where id=v_id and state='expired') then raise exception 'FAIL: expired state not persisted'; end if;
end
$invitation_test$;
rollback;

begin;
do $deletion_test$
declare
  v_chair uuid := '30000000-0000-4000-8000-000000000001';
  v_member uuid := '30000000-0000-4000-8000-000000000002';
  v_member_id uuid;
begin
  insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values
    (v_chair,'authenticated','authenticated','phase1-delete-chair@example.invalid','',clock_timestamp(),'{}','{}',clock_timestamp(),clock_timestamp()),
    (v_member,'authenticated','authenticated','phase1-delete-member@example.invalid','',clock_timestamp(),'{}','{}',clock_timestamp(),clock_timestamp());
  insert into public.user_profiles(user_id,display_name) values(v_chair,'Delete Test Chairman'),(v_member,'Delete Test Member');
  insert into public.club_memberships(user_id,status,invited_email,activated_at)
  values(v_chair,'active','phase1-delete-chair@example.invalid',clock_timestamp()),
        (v_member,'active','phase1-delete-member@example.invalid',clock_timestamp());
  select id into v_member_id from public.club_memberships where user_id=v_member;
  insert into public.role_assignments(membership_id,role_key,assigned_by)
  select id,'chairman',v_chair from public.club_memberships where user_id=v_chair;
  insert into public.role_assignments(membership_id,role_key,assigned_by) values(v_member_id,'secretary',v_chair);
  insert into public.invitation_requests(request_key,invited_email,role_key,requested_by,state,auth_user_id,sent_at)
  values('30000000-0000-4000-8000-000000000005','phase1-delete-member@example.invalid','secretary',v_member,'sent',v_member,clock_timestamp());

  begin
    delete from auth.users where id=v_chair;
    raise exception 'FAIL: active Chairman account deletion unexpectedly succeeded';
  exception when check_violation then
    if sqlerrm <> 'chairman_handover_required' then raise; end if;
  end;
  if not exists(select 1 from auth.users where id=v_chair) then raise exception 'FAIL: Chairman user was deleted despite handover guard'; end if;

  delete from auth.users where id=v_member;
  if exists(select 1 from auth.users where id=v_member) then raise exception 'FAIL: ordinary Auth user was not deleted'; end if;
  if not exists(select 1 from public.club_memberships where id=v_member_id and user_id is null and status='revoked' and revoked_at is not null) then
    raise exception 'FAIL: deleted user membership was not archived/revoked';
  end if;
  if not exists(select 1 from public.role_assignments where membership_id=v_member_id and role_key='secretary' and revoked_at is not null and revoked_by is null) then
    raise exception 'FAIL: role assignment history was not retained/revoked';
  end if;
  if not exists(select 1 from public.invitation_requests where request_key='30000000-0000-4000-8000-000000000005' and requested_by is null and auth_user_id is null) then
    raise exception 'FAIL: invitation audit record did not survive account deletion';
  end if;
  if not exists(select 1 from public.audit_events where action_key='auth_user_deleted' and entity_id=v_member_id::text and actor_user_id is null) then
    raise exception 'FAIL: system deletion audit event missing';
  end if;
end
$deletion_test$;
rollback;

-- Phase 1 transactional identity workflow extension — REVIEW DRAFT ONLY.
-- Apply only after identity_roles_review_draft.sql to disposable Union Test.
-- This file is not a production migration.
begin;
create table public.invitation_requests (
 id uuid primary key default gen_random_uuid(),
 request_key uuid not null unique,
 invited_email text not null check(invited_email=lower(btrim(invited_email)) and length(invited_email) between 3 and 320),
 role_key text not null check(role_key in ('vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team')),
 requested_by uuid not null references auth.users(id) on delete restrict,
 state text not null default 'queued' check(state in ('queued','sending','sent','failed','accepted','cancelled','expired')),
 auth_user_id uuid references auth.users(id) on delete set null,
 expires_at timestamptz not null default(clock_timestamp()+interval '7 days'),
 sent_at timestamptz, accepted_at timestamptz, cancelled_at timestamptz,
 last_error_code text check(last_error_code is null or length(last_error_code)<=80),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 check(expires_at>created_at),
 check((state='sent' and sent_at is not null) or state<>'sent'),
 check((state='accepted' and accepted_at is not null and auth_user_id is not null) or state<>'accepted'),
 check((state='cancelled' and cancelled_at is not null) or state<>'cancelled')
);
create unique index invitation_one_open_email_idx on public.invitation_requests(invited_email) where state in ('queued','sending','sent');
create index invitation_requests_state_created_idx on public.invitation_requests(state,created_at);
alter table public.invitation_requests enable row level security;
revoke all on public.invitation_requests from public,anon,authenticated;
grant select on public.invitation_requests to authenticated;
create policy invitation_select_chairman_only on public.invitation_requests for select to authenticated using((select private.can_manage_club_roles()));
create trigger invitation_requests_set_updated_at before update on public.invitation_requests for each row execute function private.set_updated_at();

create or replace function private.assert_chairman(_actor uuid) returns void
language plpgsql security definer set search_path=''
as $$
begin
 if _actor is null or not exists(select 1 from public.club_memberships m join public.role_assignments r on r.membership_id=m.id
   where m.user_id=_actor and m.status='active' and r.role_key='chairman' and r.revoked_at is null) then
   raise exception using errcode='42501',message='chairman_required';
 end if;
end $$;
revoke all on function private.assert_chairman(uuid) from public,anon,authenticated;

create or replace function public.club_admin_begin_invitation(_actor uuid,_email text,_role_key text,_request_key uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_email text;
begin
 perform private.assert_chairman(_actor);
 v_email:=lower(btrim(coalesce(_email,'')));
 if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' or length(v_email)>320
 or _role_key not in ('vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team') or _request_key is null then
 raise exception using errcode='22023',message='invalid_invitation'; end if;
 if exists(select 1 from auth.users where id=_actor and lower(email)=v_email) then raise exception using errcode='22023',message='self_assignment_not_allowed'; end if;
 update public.invitation_requests set state='expired' where invited_email=v_email and state in ('queued','failed','sent') and expires_at<=clock_timestamp();
 select id into v_id from public.invitation_requests where request_key=_request_key;
 if v_id is not null then
   if not exists(select 1 from public.invitation_requests where id=v_id and requested_by=_actor and invited_email=v_email and role_key=_role_key) then
     raise exception using errcode='23505',message='idempotency_key_conflict'; end if;
   return v_id;
 end if;
 if exists(select 1 from public.club_memberships where invited_email=v_email and status in ('active','suspended')) then
   raise exception using errcode='23505',message='email_already_has_membership'; end if;
 insert into public.invitation_requests(request_key,invited_email,role_key,requested_by) values(_request_key,v_email,_role_key,_actor) returning id into v_id;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(_actor,'invitation_requested','invitation_request',v_id::text,jsonb_build_object('role_key',_role_key,'state','queued'));
 return v_id;
end $$;

-- Single-winner queue claim prevents parallel Auth Admin invite calls for one request.
create or replace function public.club_admin_claim_invitation(_invitation_id uuid)
returns table(id uuid,invited_email text,role_key text,requested_by uuid)
language plpgsql security definer set search_path=''
as $$
begin
 update public.invitation_requests i set state='sending',last_error_code=null
 where i.id=_invitation_id and i.state in ('queued','failed') and i.expires_at>clock_timestamp()
 returning i.id,i.invited_email,i.role_key,i.requested_by into id,invited_email,role_key,requested_by;
 if id is null then
   update public.invitation_requests set state='expired' where invitation_requests.id=_invitation_id
   and state in ('queued','failed','sent') and expires_at<=clock_timestamp();
   return;
 end if;
 return next;
end $$;

-- This commits membership + role + invitation state + audit together after Auth Admin succeeds.
create or replace function public.club_admin_finish_invitation(_invitation_id uuid,_success boolean,_auth_user_id uuid default null,_error_code text default null)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.invitation_requests%rowtype; v_mid uuid;
begin
 select * into v from public.invitation_requests where id=_invitation_id for update;
 if not found or v.state<>'sending' then raise exception using errcode='40001',message='invitation_not_claimed'; end if;
 if not _success then
  update public.invitation_requests set state='failed',last_error_code=left(coalesce(_error_code,'auth_invite_failed'),80) where id=v.id;
  insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,outcome,details)
  values(v.requested_by,'invitation_delivery_failed','invitation_request',v.id::text,'failure',jsonb_build_object('error_code',left(coalesce(_error_code,'auth_invite_failed'),80)));
  return 'failed';
 end if;
 if _auth_user_id is null or not exists(select 1 from auth.users where id=_auth_user_id and lower(email)=v.invited_email) then
  update public.invitation_requests set state='failed',last_error_code='auth_email_mismatch' where id=v.id;
  insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,outcome,details)
  values(v.requested_by,'invitation_delivery_rejected','invitation_request',v.id::text,'failure','{"error_code":"auth_email_mismatch"}');
  return 'failed';
 end if;
 insert into public.club_memberships(user_id,status,invited_email,invited_by)
 values(_auth_user_id,'invited',v.invited_email,v.requested_by)
 on conflict(user_id) do update set status='invited',invited_email=excluded.invited_email,invited_by=excluded.invited_by,activated_at=null,revoked_at=null
 where public.club_memberships.status='revoked' returning id into v_mid;
 if v_mid is null then select id into v_mid from public.club_memberships where user_id=_auth_user_id and invited_email=v.invited_email and status='invited'; end if;
 if v_mid is null then update public.invitation_requests set state='failed',last_error_code='membership_conflict' where id=v.id; return 'failed'; end if;
 insert into public.role_assignments(membership_id,role_key,assigned_by) values(v_mid,v.role_key,v.requested_by)
 on conflict(membership_id,role_key) where revoked_at is null do nothing;
 update public.invitation_requests set state='sent',auth_user_id=_auth_user_id,sent_at=clock_timestamp(),last_error_code=null where id=v.id;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(v.requested_by,'invitation_sent','invitation_request',v.id::text,jsonb_build_object('role_key',v.role_key,'state','sent'));
 return 'sent';
end $$;

create or replace function public.club_admin_activate_invitation(_actor uuid,_invitation_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.invitation_requests%rowtype; u auth.users%rowtype;
begin
 select * into v from public.invitation_requests where id=_invitation_id for update;
 if not found or v.state<>'sent' then raise exception using errcode='22023',message='invitation_not_activatable'; end if;
 if v.expires_at<=clock_timestamp() then update public.invitation_requests set state='expired' where id=v.id; raise exception using errcode='22023',message='invitation_expired'; end if;
 select * into u from auth.users where id=_actor;
 if u.id is null or lower(coalesce(u.email,''))<>v.invited_email or u.email_confirmed_at is null or v.auth_user_id<>_actor then
 raise exception using errcode='42501',message='verified_invited_identity_required'; end if;
 update public.club_memberships set status='active',activated_at=coalesce(activated_at,clock_timestamp())
 where user_id=_actor and invited_email=v.invited_email and status='invited';
 if not found then raise exception using errcode='40001',message='membership_not_activatable'; end if;
 update public.invitation_requests set state='accepted',accepted_at=clock_timestamp() where id=v.id;
 insert into public.user_profiles(user_id,display_name) values(_actor,coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'),''),split_part(v.invited_email,'@',1))) on conflict(user_id) do nothing;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(_actor,'invitation_accepted','invitation_request',v.id::text,jsonb_build_object('role_key',v.role_key));
 return 'active';
end $$;

create or replace function public.club_admin_cancel_invitation(_actor uuid,_invitation_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.invitation_requests%rowtype;
begin
 perform private.assert_chairman(_actor);
 select * into v from public.invitation_requests where id=_invitation_id for update;
 if not found or v.state not in ('queued','failed','sent') then raise exception using errcode='22023',message='invitation_not_cancellable'; end if;
 update public.invitation_requests set state='cancelled',cancelled_at=clock_timestamp() where id=v.id;
 update public.club_memberships set status='revoked',revoked_at=clock_timestamp() where user_id=v.auth_user_id and status='invited';
 update public.role_assignments r set revoked_at=clock_timestamp(),revoked_by=_actor from public.club_memberships m
 where r.membership_id=m.id and m.user_id=v.auth_user_id and r.revoked_at is null;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(_actor,'invitation_cancelled','invitation_request',v.id::text,jsonb_build_object('role_key',v.role_key));
 return 'cancelled';
end $$;

create or replace function public.club_admin_manage_membership(_actor uuid,_target_user_id uuid,_action text)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.club_memberships%rowtype;
begin
 perform private.assert_chairman(_actor);
 if _target_user_id=_actor then raise exception using errcode='22023',message='self_management_not_allowed'; end if;
 select * into v from public.club_memberships where user_id=_target_user_id for update;
 if not found then raise exception using errcode='P0002',message='membership_not_found'; end if;
 if _action='suspend' and v.status='active' then update public.club_memberships set status='suspended' where id=v.id;
 elsif _action='restore' and v.status='suspended' then update public.club_memberships set status='active' where id=v.id;
 elsif _action='revoke' and v.status in ('active','suspended','invited') then
  if exists(select 1 from public.role_assignments where membership_id=v.id and role_key='chairman' and revoked_at is null) then raise exception using errcode='23514',message='chairman_handover_required'; end if;
  update public.club_memberships set status='revoked',revoked_at=clock_timestamp() where id=v.id;
  update public.role_assignments set revoked_at=clock_timestamp(),revoked_by=_actor where membership_id=v.id and revoked_at is null;
 else raise exception using errcode='22023',message='invalid_membership_transition'; end if;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details) values(_actor,'membership_'||_action,'club_membership',v.id::text,jsonb_build_object('from_status',v.status,'to_action',_action));
 return case _action when 'suspend' then 'suspended' when 'restore' then 'restored' when 'revoke' then 'revoked' else 'invalid' end;
end $$;

create or replace function public.club_admin_change_role(_actor uuid,_target_user_id uuid,_role_key text,_action text,_note text default null)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.club_memberships%rowtype;
begin
 perform private.assert_chairman(_actor);
 if _target_user_id=_actor or _role_key not in ('vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team')
 or _action not in ('assign','revoke') or length(coalesce(_note,''))>500 then raise exception using errcode='22023',message='invalid_role_change'; end if;
 select * into v from public.club_memberships where user_id=_target_user_id and status='active' for update;
 if not found then raise exception using errcode='P0002',message='active_membership_required'; end if;
 if _action='assign' then insert into public.role_assignments(membership_id,role_key,assigned_by,note) values(v.id,_role_key,_actor,nullif(btrim(_note),''));
 else update public.role_assignments set revoked_at=clock_timestamp(),revoked_by=_actor,note=coalesce(nullif(btrim(_note),''),note)
 where membership_id=v.id and role_key=_role_key and revoked_at is null;
 if not found then raise exception using errcode='P0002',message='active_role_not_found'; end if; end if;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details) values(_actor,'role_'||_action,'club_membership',v.id::text,jsonb_build_object('role_key',_role_key,'note_present',nullif(btrim(_note),'') is not null));
 return _action||'d';
end $$;

create or replace function public.club_admin_handover_chairman(_actor uuid,_successor_user_id uuid,_note text default null)
returns text language plpgsql security definer set search_path=''
as $$
declare old_role public.role_assignments%rowtype; new_member public.club_memberships%rowtype;
begin
 perform pg_advisory_xact_lock(hashtext('timau_union_fc_chairman_handover'));
 perform private.assert_chairman(_actor);
 if _successor_user_id=_actor or length(coalesce(_note,''))>500 then raise exception using errcode='22023',message='invalid_handover'; end if;
 select r.* into old_role from public.role_assignments r join public.club_memberships m on m.id=r.membership_id
 where r.role_key='chairman' and r.revoked_at is null and m.status='active' for update of r;
 if not found or not exists(select 1 from public.club_memberships where user_id=_actor and id=old_role.membership_id) then
 raise exception using errcode='42501',message='current_chairman_required'; end if;
 select * into new_member from public.club_memberships where user_id=_successor_user_id and status='active' for update;
 if not found then raise exception using errcode='P0002',message='active_successor_required'; end if;
 if exists(select 1 from public.role_assignments where membership_id=new_member.id and role_key='chairman' and revoked_at is null) then raise exception using errcode='23505',message='successor_already_chairman'; end if;
 update public.role_assignments set revoked_at=clock_timestamp(),revoked_by=_actor,note=coalesce(nullif(btrim(_note),''),note) where id=old_role.id;
 insert into public.role_assignments(membership_id,role_key,assigned_by,note) values(new_member.id,'chairman',_actor,nullif(btrim(_note),''));
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(_actor,'chairman_handover','role_assignment',new_member.id::text,jsonb_build_object('previous_membership_id',old_role.membership_id,'successor_membership_id',new_member.id,'note_present',nullif(btrim(_note),'') is not null));
 return 'transferred';
end $$;

revoke all on function public.club_admin_begin_invitation(uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function public.club_admin_claim_invitation(uuid) from public,anon,authenticated;
revoke all on function public.club_admin_finish_invitation(uuid,boolean,uuid,text) from public,anon,authenticated;
revoke all on function public.club_admin_activate_invitation(uuid,uuid) from public,anon,authenticated;
revoke all on function public.club_admin_cancel_invitation(uuid,uuid) from public,anon,authenticated;
revoke all on function public.club_admin_manage_membership(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.club_admin_change_role(uuid,uuid,text,text,text) from public,anon,authenticated;
revoke all on function public.club_admin_handover_chairman(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.club_admin_begin_invitation(uuid,text,text,uuid) to service_role;
grant execute on function public.club_admin_claim_invitation(uuid) to service_role;
grant execute on function public.club_admin_finish_invitation(uuid,boolean,uuid,text) to service_role;
grant execute on function public.club_admin_activate_invitation(uuid,uuid) to service_role;
grant execute on function public.club_admin_cancel_invitation(uuid,uuid) to service_role;
grant execute on function public.club_admin_manage_membership(uuid,uuid,text) to service_role;
grant execute on function public.club_admin_change_role(uuid,uuid,text,text,text) to service_role;
grant execute on function public.club_admin_handover_chairman(uuid,uuid,text) to service_role;
commit;

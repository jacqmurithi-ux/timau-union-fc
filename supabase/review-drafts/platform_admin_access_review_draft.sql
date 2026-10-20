-- Timau Union FC — platform administrator approval and role governance
-- REVIEW DRAFT ONLY. Union Test first. Never apply to production without explicit approval.
-- Requires identity_roles_review_draft.sql, transactional_identity_workflows_review_draft.sql,
-- rate_limit_review_draft.sql and auth_user_deletion_archive_review_draft.sql.
begin;

create table private.platform_admins (
  user_id uuid primary key references auth.users(id) on delete restrict,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  note text not null check (length(btrim(note)) between 1 and 500)
);
alter table private.platform_admins enable row level security;
create policy platform_admins_deny_all on private.platform_admins
  for all to public using (false) with check (false);
revoke all on table private.platform_admins from public, anon, authenticated, service_role;

-- Bootstrap is deliberately out-of-band: after a trusted first platform-admin account has
-- signed up, a database owner inserts its verified Auth UUID here. No browser API can self-promote.
create function public.club_platform_admin_is_authorized(_actor uuid)
returns boolean
language sql stable security definer set search_path=''
as $$
  select _actor is not null and exists (
    select 1 from private.platform_admins pa
    join auth.users u on u.id=pa.user_id
    where pa.user_id=_actor and pa.enabled=true and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.club_platform_admin_is_authorized(uuid) from public, anon, authenticated;
grant execute on function public.club_platform_admin_is_authorized(uuid) to service_role;

create function public.club_platform_admin_approve_signup(
  _actor uuid, _target_user_id uuid, _role_key text, _note text default null
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare
  v_email text;
  v_confirmed_at timestamptz;
  v_metadata jsonb;
  v_name text;
  v_membership_id uuid;
  v_status text;
  v_role_id uuid;
begin
  if not public.club_platform_admin_is_authorized(_actor) then
    raise exception using errcode='42501', message='platform_admin_required';
  end if;
  if _target_user_id is null or _target_user_id=_actor or _role_key is null or _role_key not in ('chairman','vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team') then
    raise exception using errcode='22023', message='invalid_platform_approval';
  end if;
  if _note is not null and length(_note)>500 then
    raise exception using errcode='22023', message='invalid_note';
  end if;

  select lower(btrim(u.email)),u.email_confirmed_at,u.raw_user_meta_data
    into v_email,v_confirmed_at,v_metadata
    from auth.users u where u.id=_target_user_id for update;
  if not found or v_email is null or v_confirmed_at is null then
    raise exception using errcode='42501', message='verified_signup_required';
  end if;
  v_name := left(btrim(coalesce(v_metadata->>'display_name',v_metadata->>'full_name',split_part(v_email,'@',1))),120);
  if length(v_name)=0 then v_name := 'Club member'; end if;

  insert into public.user_profiles(user_id,display_name)
    values(_target_user_id,v_name)
    on conflict(user_id) do update set display_name=excluded.display_name;

  select id,status into v_membership_id,v_status
    from public.club_memberships where user_id=_target_user_id for update;
  if not found then
    insert into public.club_memberships(user_id,status,invited_email,invited_by,activated_at)
      values(_target_user_id,'active',v_email,_actor,clock_timestamp())
      returning id into v_membership_id;
    v_status := 'active';
  elsif v_status='invited' then
    update public.club_memberships set status='active', invited_email=v_email,
      invited_by=coalesce(invited_by,_actor), activated_at=coalesce(activated_at,clock_timestamp())
      where id=v_membership_id;
    v_status := 'active';
  elsif v_status<>'active' then
    raise exception using errcode='22023', message='membership_not_approvable';
  end if;

  insert into public.role_assignments(membership_id,role_key,assigned_by,note)
    values(v_membership_id,_role_key,_actor,nullif(btrim(_note),''))
    on conflict (membership_id,role_key) where revoked_at is null do nothing
    returning id into v_role_id;

  insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,outcome,details)
    values(_actor,'platform_signup_approved','club_membership',v_membership_id::text,'success',
      jsonb_build_object('target_user_id',_target_user_id,'role_key',_role_key,'note',nullif(btrim(_note),'')));
  return jsonb_build_object('membership_id',v_membership_id,'status',v_status,'role_key',_role_key,'role_added',v_role_id is not null);
end;
$$;
revoke all on function public.club_platform_admin_approve_signup(uuid,uuid,text,text) from public, anon, authenticated;
grant execute on function public.club_platform_admin_approve_signup(uuid,uuid,text,text) to service_role;

create function public.club_platform_admin_change_role(
  _actor uuid, _target_user_id uuid, _role_key text, _action text, _note text default null
) returns text
language plpgsql security definer set search_path=''
as $$
declare
  v_membership_id uuid;
  v_role_id uuid;
begin
  if not public.club_platform_admin_is_authorized(_actor) then
    raise exception using errcode='42501', message='platform_admin_required';
  end if;
  if _target_user_id is null or _target_user_id=_actor
    or _role_key is null or _role_key not in ('chairman','vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team')
    or _action is null or _action not in ('assign','revoke')
    or (_note is not null and length(_note)>500) then
    raise exception using errcode='22023', message='invalid_role_change';
  end if;
  if _action='revoke' and _role_key='chairman' then
    raise exception using errcode='22023', message='chairman_handover_required';
  end if;
  select id into v_membership_id from public.club_memberships
    where user_id=_target_user_id and status='active' for update;
  if not found then raise exception using errcode='P0002', message='active_membership_required'; end if;

  if _action='assign' then
    insert into public.role_assignments(membership_id,role_key,assigned_by,note)
      values(v_membership_id,_role_key,_actor,nullif(btrim(_note),''))
      on conflict (membership_id,role_key) where revoked_at is null do nothing;
  else
    update public.role_assignments set revoked_at=clock_timestamp(),revoked_by=_actor
      where membership_id=v_membership_id and role_key=_role_key and revoked_at is null
      returning id into v_role_id;
    if v_role_id is null then raise exception using errcode='P0002', message='active_role_not_found'; end if;
  end if;

  insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,outcome,details)
    values(_actor,'platform_role_'||_action,'role_assignment',v_membership_id::text,'success',
      jsonb_build_object('target_user_id',_target_user_id,'role_key',_role_key,'note',nullif(btrim(_note),'')));
  return _action||'_ok';
end;
$$;
revoke all on function public.club_platform_admin_change_role(uuid,uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.club_platform_admin_change_role(uuid,uuid,text,text,text) to service_role;

commit;

-- One-time bootstrap, run only by the database owner after verifying the intended Auth user's UUID:
-- insert into private.platform_admins(user_id,enabled,created_by,note)
-- values ('REPLACE_WITH_VERIFIED_PLATFORM_ADMIN_AUTH_UUID',true,null,'Initial platform administrator bootstrap');

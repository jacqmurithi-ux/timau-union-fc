-- Allow the already-defined Sponsor (own contributions only) role to be assigned.
-- The UI offered this role, but both the database role constraint and assignment RPC rejected it.

alter table private.role_assignments
  drop constraint if exists role_assignments_role_key_check;

alter table private.role_assignments
  add constraint role_assignments_role_key_check
  check (role_key in (
    'chairman', 'vice_chairman', 'secretary', 'team_manager',
    'treasurer', 'coach', 'sponsor_lead', 'sponsor', 'media_team'
  ));

create or replace function public.admin_assign_club_role(
  _target_user_id uuid,
  _new_role text,
  _reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_status text;
  v_verified boolean;
  v_old_roles jsonb;
begin
  if v_actor is null or not private.is_active_platform_admin(v_actor) then
    raise exception 'Active Platform Admin required' using errcode = '42501';
  end if;
  if _target_user_id is null or _target_user_id = v_actor then
    raise exception 'Invalid target account' using errcode = '22023';
  end if;
  if _new_role not in ('chairman', 'vice_chairman', 'secretary', 'team_manager',
                       'treasurer', 'coach', 'sponsor_lead', 'sponsor', 'media_team') then
    raise exception 'Unsupported club role' using errcode = '22023';
  end if;
  if _reason is null or length(pg_catalog.btrim(_reason)) < 3 or length(_reason) > 1000 then
    raise exception 'A reason of 3 to 1000 characters is required' using errcode = '22023';
  end if;

  select aa.status, u.email_confirmed_at is not null
    into v_status, v_verified
  from private.account_access aa
  join auth.users u on u.id = aa.user_id
  where aa.user_id = _target_user_id
  for update of aa;

  if not found then
    raise exception 'Access request not found' using errcode = 'P0002';
  end if;
  if v_status <> 'approved' or not coalesce(v_verified, false) then
    raise exception 'Target must be email-verified and approved first' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.jsonb_agg(role_key order by role_key), '[]'::jsonb)
    into v_old_roles
  from private.role_assignments
  where user_id = _target_user_id and active;

  update private.role_assignments
  set active = false, revoked_at = pg_catalog.now(), revoked_by = v_actor
  where user_id = _target_user_id and active;

  insert into private.role_assignments(user_id, role_key, assigned_by, reason)
  values (_target_user_id, _new_role, v_actor, _reason);

  insert into private.audit_events(actor_user_id, target_user_id, action_key, old_value, new_value, reason)
  values (v_actor, _target_user_id, 'club_role_changed',
          pg_catalog.jsonb_build_object('roles', v_old_roles),
          pg_catalog.jsonb_build_object('role', _new_role), _reason);

  return pg_catalog.jsonb_build_object('ok', true, 'old_roles', v_old_roles, 'new_role', _new_role);
end;
$function$;

revoke all on function public.admin_assign_club_role(uuid, text, text) from public, anon;
grant execute on function public.admin_assign_club_role(uuid, text, text) to authenticated;

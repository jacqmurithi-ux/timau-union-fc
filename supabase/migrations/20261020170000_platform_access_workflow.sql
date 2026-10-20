-- Timau Union FC — Platform access workflow
-- DRAFT ONLY. Do not apply to production until the complete SQL and rollback are reviewed
-- and the owner explicitly approves the migration.
-- Target project: owvvimydkjsjlrmnzvdi (production)
-- No existing public application tables were found during read-only inspection.
-- All objects are additive. Existing auth.users rows are not backfilled or modified.
-- Signup trigger only creates access/profile rows for future auth.users inserts.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Member'
    check (length(btrim(display_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table private.account_access (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended', 'revoked')),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete set null,
  decision_reason text check (decision_reason is null or length(decision_reason) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint account_access_decision_consistency check (
    (status = 'pending' and decided_at is null and decided_by is null)
    or (status <> 'pending' and decided_at is not null)
  )
);

create table private.platform_admins (
  user_id uuid primary key references auth.users(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  disabled_at timestamptz,
  disabled_by uuid references auth.users(id) on delete set null,
  constraint platform_admin_lifecycle check (
    (active and disabled_at is null)
    or (not active and disabled_at is not null)
  )
);

create table private.role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  role_key text not null check (role_key in (
    'chairman', 'vice_chairman', 'secretary', 'team_manager',
    'treasurer', 'coach', 'sponsor_lead', 'media_team'
  )),
  active boolean not null default true,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  reason text check (reason is null or length(reason) <= 1000),
  constraint role_assignment_lifecycle check (
    (active and revoked_at is null)
    or (not active and revoked_at is not null)
  )
);

create unique index role_assignments_one_active_role_per_user
  on private.role_assignments(user_id) where active;

-- Keep the club's top leadership singular even if two admins act concurrently.
create unique index role_assignments_one_active_chairman
  on private.role_assignments(role_key)
  where active and role_key = 'chairman';

create index account_access_status_requested_idx
  on private.account_access(status, requested_at);

create table private.audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action_key text not null check (length(btrim(action_key)) between 1 and 100),
  old_value jsonb not null default '{}'::jsonb check (jsonb_typeof(old_value) = 'object'),
  new_value jsonb not null default '{}'::jsonb check (jsonb_typeof(new_value) = 'object'),
  reason text check (reason is null or length(reason) <= 1000),
  created_at timestamptz not null default now()
);

create index audit_events_created_at_idx on private.audit_events(created_at desc);
create index audit_events_target_created_at_idx
  on private.audit_events(target_user_id, created_at desc);

-- RLS is enabled on every application table. The private schema must also remain
-- absent from Supabase Data API exposed schemas. Access is through the RPCs below only.
alter table private.user_profiles enable row level security;
alter table private.account_access enable row level security;
alter table private.platform_admins enable row level security;
alter table private.role_assignments enable row level security;
alter table private.audit_events enable row level security;

revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all sequences in schema private from public, anon, authenticated;
revoke all on all functions in schema private from public, anon, authenticated;

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$function$;

revoke all on function private.touch_updated_at() from public, anon, authenticated;

create trigger user_profiles_touch_updated_at
before update on private.user_profiles
for each row execute function private.touch_updated_at();

create trigger account_access_touch_updated_at
before update on private.account_access
for each row execute function private.touch_updated_at();

-- A new Auth identity gets a pending request only. User metadata is untrusted display text;
-- it never sets access status, platform admin state, or a role.
create function private.on_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_name text;
begin
  v_name := pg_catalog.left(
    pg_catalog.btrim(coalesce(new.raw_user_meta_data ->> 'display_name',
                              new.raw_user_meta_data ->> 'full_name',
                              'Member')),
    120
  );
  if v_name = '' then v_name := 'Member'; end if;

  insert into private.user_profiles(user_id, display_name)
  values (new.id, v_name)
  on conflict (user_id) do nothing;

  insert into private.account_access(user_id, status)
  values (new.id, 'pending')
  on conflict (user_id) do nothing;

  return new;
end;
$function$;

revoke all on function private.on_auth_user_created() from public, anon, authenticated;

create trigger timau_auth_user_pending_access
after insert on auth.users
for each row execute function private.on_auth_user_created();

create function private.is_active_platform_admin(_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select _user_id is not null and exists (
    select 1
    from private.platform_admins pa
    join auth.users u on u.id = pa.user_id
    join private.account_access aa on aa.user_id = pa.user_id
    where pa.user_id = _user_id
      and pa.active
      and u.email_confirmed_at is not null
      and aa.status = 'approved'
  );
$function$;

revoke all on function private.is_active_platform_admin(uuid) from public, anon, authenticated;

-- Self-status endpoint: reveals only the caller's own approval state and email-verification
-- state, never another account or any private club records.
create function public.get_my_access_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_status text;
  v_email_verified boolean;
  v_role text;
  v_is_admin boolean;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select u.email_confirmed_at is not null, aa.status, ra.role_key,
         (private.is_active_platform_admin(v_uid) and u.email_confirmed_at is not null)
    into v_email_verified, v_status, v_role, v_is_admin
  from auth.users u
  left join private.account_access aa on aa.user_id = u.id
  left join private.role_assignments ra on ra.user_id = u.id and ra.active
  where u.id = v_uid;

  if not found then
    raise exception 'Account not found' using errcode = 'P0002';
  end if;

  return pg_catalog.jsonb_build_object(
    'email_verified', coalesce(v_email_verified, false),
    'status', case when coalesce(v_is_admin, false) then 'platform_admin' else coalesce(v_status, 'pending') end,
    'platform_admin', coalesce(v_is_admin, false),
    'role', case when v_status = 'approved' and v_email_verified then v_role else null end,
    'access_granted', coalesce(v_is_admin, false) or coalesce(v_status = 'approved' and v_email_verified and v_role is not null, false)
  );
end;
$function$;

revoke all on function public.get_my_access_status() from public, anon;
grant execute on function public.get_my_access_status() to authenticated;

-- Admin queue. Explicit active Platform Admin check is required on this RPC.
create function public.admin_list_access_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null or not private.is_active_platform_admin(v_uid) then
    raise exception 'Active Platform Admin required' using errcode = '42501';
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'user_id', u.id,
    'email', u.email,
    'email_verified', u.email_confirmed_at is not null,
    'display_name', p.display_name,
    'status', aa.status,
    'requested_at', aa.requested_at,
    'decided_at', aa.decided_at,
    'decided_by', aa.decided_by,
    'role', ra.role_key
  ) order by case aa.status when 'pending' then 0 else 1 end, aa.requested_at desc), '[]'::jsonb)
  into v_result
  from private.account_access aa
  join auth.users u on u.id = aa.user_id
  left join private.user_profiles p on p.user_id = u.id
  left join private.role_assignments ra on ra.user_id = u.id and ra.active;

  return v_result;
end;
$function$;

revoke all on function public.admin_list_access_requests() from public, anon;
grant execute on function public.admin_list_access_requests() to authenticated;

-- Approval, rejection, suspension, reinstatement (approved), and revocation.
-- The check, status write and audit event occur in one database transaction.
create function public.admin_set_account_status(
  _target_user_id uuid,
  _new_status text,
  _reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_old_status text;
  v_verified boolean;
  v_old_roles jsonb;
begin
  if v_actor is null or not private.is_active_platform_admin(v_actor) then
    raise exception 'Active Platform Admin required' using errcode = '42501';
  end if;

  if _new_status not in ('approved', 'rejected', 'suspended', 'revoked') then
    raise exception 'Unsupported account status' using errcode = '22023';
  end if;
  if _target_user_id is null or _target_user_id = v_actor then
    raise exception 'Invalid target account' using errcode = '22023';
  end if;
  if _reason is null or length(pg_catalog.btrim(_reason)) < 3 or length(_reason) > 1000 then
    raise exception 'A reason of 3 to 1000 characters is required' using errcode = '22023';
  end if;

  select aa.status, u.email_confirmed_at is not null
    into v_old_status, v_verified
  from private.account_access aa
  join auth.users u on u.id = aa.user_id
  where aa.user_id = _target_user_id
  for update of aa;

  if not found then
    raise exception 'Access request not found' using errcode = 'P0002';
  end if;

  if _new_status = 'approved' and not coalesce(v_verified, false) then
    raise exception 'Email verification is required before approval' using errcode = '22023';
  end if;

  update private.account_access
  set status = _new_status, decided_at = pg_catalog.now(),
      decided_by = v_actor, decision_reason = _reason
  where user_id = _target_user_id;

  -- Rejection/revocation removes active club roles in the same transaction.
  -- Suspension keeps the assignment for a deliberate reinstatement, but all access
  -- remains blocked while the account status is suspended.
  if _new_status in ('rejected', 'revoked') then
    select coalesce(pg_catalog.jsonb_agg(role_key order by role_key), '[]'::jsonb)
      into v_old_roles
    from private.role_assignments
    where user_id = _target_user_id and active;

    update private.role_assignments
    set active = false, revoked_at = pg_catalog.now(), revoked_by = v_actor
    where user_id = _target_user_id and active;

    if pg_catalog.jsonb_array_length(v_old_roles) > 0 then
      insert into private.audit_events(actor_user_id, target_user_id, action_key, old_value, new_value, reason)
      values (v_actor, _target_user_id, 'club_role_changed',
              pg_catalog.jsonb_build_object('roles', v_old_roles),
              pg_catalog.jsonb_build_object('roles', '[]'::jsonb), _reason);
    end if;
  end if;

  insert into private.audit_events(actor_user_id, target_user_id, action_key, old_value, new_value, reason)
  values (v_actor, _target_user_id, 'account_status_changed',
          pg_catalog.jsonb_build_object('status', v_old_status),
          pg_catalog.jsonb_build_object('status', _new_status), _reason);

  return pg_catalog.jsonb_build_object('ok', true, 'old_status', v_old_status, 'new_status', _new_status);
end;
$function$;

revoke all on function public.admin_set_account_status(uuid, text, text) from public, anon;
grant execute on function public.admin_set_account_status(uuid, text, text) to authenticated;

-- Assign/change the user's single active club role. The account must be approved and verified.
create function public.admin_assign_club_role(
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
                       'treasurer', 'coach', 'sponsor_lead', 'media_team') then
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

create function public.admin_get_audit_events(_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_result jsonb;
begin
  if v_actor is null or not private.is_active_platform_admin(v_actor) then
    raise exception 'Active Platform Admin required' using errcode = '42501';
  end if;
  if _limit is null or _limit < 1 or _limit > 500 then
    raise exception 'Limit must be between 1 and 500' using errcode = '22023';
  end if;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id', e.id,
    'actor_user_id', e.actor_user_id,
    'actor_email', actor.email,
    'target_user_id', e.target_user_id,
    'target_email', target.email,
    'action', e.action_key,
    'old_value', e.old_value,
    'new_value', e.new_value,
    'reason', e.reason,
    'timestamp', e.created_at
  ) order by e.created_at desc), '[]'::jsonb)
  into v_result
  from (
    select * from private.audit_events order by created_at desc limit _limit
  ) e
  left join auth.users actor on actor.id = e.actor_user_id
  left join auth.users target on target.id = e.target_user_id;

  return v_result;
end;
$function$;

revoke all on function public.admin_get_audit_events(integer) from public, anon;
grant execute on function public.admin_get_audit_events(integer) to authenticated;

-- Platform Admins are bootstrapped only by a human-run SQL Editor statement supplied
-- separately after review. No browser-facing RPC can create or activate a Platform Admin.
-- Existing auth.users rows are intentionally not backfilled: review the account inventory
-- and use the reviewed bootstrap snippet for the first Platform Admin.

commit;

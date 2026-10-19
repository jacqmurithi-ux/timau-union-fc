-- Timau Union FC — Phase 1 identity and role-governance schema (REVIEW DRAFT ONLY)
-- DO NOT APPLY to production. Review grants, ownership, RLS and tests first.
-- Intended for a disposable/test Supabase project after explicit review.
-- No service-role key or other secret belongs in the client.

begin;

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  contact_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  status text not null default 'invited'
    check (status in ('invited','active','suspended','revoked')),
  invited_email text not null,
  invited_by uuid references auth.users(id) on delete set null,
  activated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invited_email_lowercase check (invited_email = lower(btrim(invited_email)))
);

create table if not exists public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  role_key text not null check (role_key in (
    'chairman','vice_chairman','secretary','team_manager','treasurer',
    'coach','sponsor_lead','media_team'
  )),
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  note text,
  constraint role_assignment_active_unique unique (membership_id, role_key, assigned_at)
);

create index if not exists role_assignments_membership_active_idx
  on public.role_assignments (membership_id, role_key)
  where revoked_at is null;

-- Prevent multiple simultaneously active assignments of the same role.
create unique index if not exists role_assignments_one_active_role_idx
  on public.role_assignments (membership_id, role_key)
  where revoked_at is null;

create table if not exists public.audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid, -- retain actor identifier even if the auth account is later deleted
  action_key text not null check (length(btrim(action_key)) between 1 and 100),
  entity_type text not null check (length(btrim(entity_type)) between 1 and 100),
  entity_id text,
  outcome text not null default 'success'
    check (outcome in ('success','denied','failure')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_events_created_at_idx
  on public.audit_events (created_at desc);
create index if not exists audit_events_actor_created_at_idx
  on public.audit_events (actor_user_id, created_at desc);

-- Enable RLS before any application use.
alter table public.user_profiles enable row level security;
alter table public.club_memberships enable row level security;
alter table public.role_assignments enable row level security;
alter table public.audit_events enable row level security;

-- Remove broad table access. Specific grants and policies are deliberately narrow.
revoke all on table public.user_profiles from anon, authenticated;
revoke all on table public.club_memberships from anon, authenticated;
revoke all on table public.role_assignments from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;

grant select on table public.user_profiles to authenticated;
grant select on table public.club_memberships to authenticated;
grant select on table public.role_assignments to authenticated;
grant select on table public.audit_events to authenticated;

-- Keep SECURITY DEFINER helpers in a non-exposed schema, never public.
-- The migration executor must be a trusted database owner; verify ownership in review.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.has_active_club_role(_role_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null and exists (
    select 1
    from public.club_memberships m
    join public.role_assignments r on r.membership_id = m.id
    where m.user_id = auth.uid()
      and m.status = 'active'
      and r.revoked_at is null
      and r.role_key = _role_key
  );
$function$;

create or replace function private.can_manage_club_roles()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null
    and private.has_active_club_role('chairman');
$function$;

revoke all on function private.has_active_club_role(text) from public, anon;
revoke all on function private.can_manage_club_roles() from public, anon;
grant execute on function private.has_active_club_role(text) to authenticated;
grant execute on function private.can_manage_club_roles() to authenticated;

-- RLS policies grant read access only; no client-side role/membership mutations.
drop policy if exists "profile_select_self_or_chairman" on public.user_profiles;
create policy "profile_select_self_or_chairman"
  on public.user_profiles for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.can_manage_club_roles())
  );

drop policy if exists "membership_select_self_or_chairman" on public.club_memberships;
create policy "membership_select_self_or_chairman"
  on public.club_memberships for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.can_manage_club_roles())
  );

drop policy if exists "role_assignment_select_self_or_chairman" on public.role_assignments;
create policy "role_assignment_select_self_or_chairman"
  on public.role_assignments for select to authenticated
  using (
    exists (
      select 1
      from public.club_memberships m
      where m.id = membership_id
        and m.user_id = (select auth.uid())
    )
    or (select public.can_manage_club_roles())
  );

-- Audit events are not readable by all authenticated users.
drop policy if exists "audit_select_chairman_only" on public.audit_events;
create policy "audit_select_chairman_only"
  on public.audit_events for select to authenticated
  using ((select public.can_manage_club_roles()));

-- Intentionally no INSERT/UPDATE/DELETE policies on these tables.
-- Trusted server-side invitation/role/audit operations must be implemented separately.
-- Ordinary clients cannot write roles, membership state or audit history.
-- The Chairman read policy is not an invitation/role-write workflow.

commit;

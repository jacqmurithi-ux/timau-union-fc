-- Timau Union FC — Phase 1 identity/role schema (REVIEW DRAFT ONLY)
-- Target production project reference recorded by owner: owvvimydkjsjlrmnzvdi
-- IMPORTANT: Do NOT run against production. No SQL has been approved or executed.
-- First test only on a verified, disposable Supabase project with a clean schema.
-- This is a review artifact, NOT a Supabase migration.
-- Trusted invitation, activation, suspension, revocation, role assignment, handover,
-- and audit writes are deliberately NOT implemented in this draft.

begin;

-- Fail rather than silently accepting pre-existing objects with unknown definitions.
create schema private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  contact_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  status text not null default 'invited'
    check (status in ('invited','active','suspended','revoked')),
  invited_email text not null
    check (invited_email = lower(btrim(invited_email))
      and length(invited_email) between 3 and 320),
  invited_by uuid references auth.users(id) on delete set null,
  activated_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint membership_lifecycle_consistent check (
    (status = 'invited' and activated_at is null and revoked_at is null)
    or (status = 'active' and activated_at is not null and revoked_at is null)
    or (status = 'suspended' and activated_at is not null and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null)
  )
);

create table public.role_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.club_memberships(id) on delete restrict,
  role_key text not null check (role_key in (
    'chairman','vice_chairman','secretary','team_manager','treasurer',
    'coach','sponsor_lead','media_team'
  )),
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  note text check (note is null or length(note) <= 500),
  constraint role_revocation_consistent check (
    (revoked_at is null and revoked_by is null)
    or revoked_at is not null
  )
);

-- One active assignment of each role per membership.
create unique index role_assignments_one_active_role_idx
  on public.role_assignments (membership_id, role_key)
  where revoked_at is null;

-- Global invariant: at most one active Chairman, even under concurrent writes.
-- A trusted handover must revoke the outgoing assignment and assign the incoming
-- Chairman in one transaction. A partial unique index is the final race-safe guard.
create unique index role_assignments_one_active_chairman_idx
  on public.role_assignments (role_key)
  where role_key = 'chairman' and revoked_at is null;

create index role_assignments_membership_active_idx
  on public.role_assignments (membership_id, role_key)
  where revoked_at is null;

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid, -- intentionally no FK: preserve actor reference after account deletion
  action_key text not null check (length(btrim(action_key)) between 1 and 100),
  entity_type text not null check (length(btrim(entity_type)) between 1 and 100),
  entity_id text check (entity_id is null or length(entity_id) <= 200),
  outcome text not null default 'success'
    check (outcome in ('success','denied','failure')),
  details jsonb not null default '{}'::jsonb
    check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default now()
);

create index audit_events_created_at_idx on public.audit_events (created_at desc);
create index audit_events_actor_created_at_idx on public.audit_events (actor_user_id, created_at desc);

-- Maintain timestamps on every row update. Function is invoker-security, not SECURITY DEFINER.
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function private.set_updated_at() from public, anon, authenticated;
create trigger user_profiles_set_updated_at
  before update on public.user_profiles
  for each row execute function private.set_updated_at();
create trigger club_memberships_set_updated_at
  before update on public.club_memberships
  for each row execute function private.set_updated_at();

-- SECURITY DEFINER functions are isolated in a non-exposed schema, fixed search_path,
-- and explicitly check the caller identity. Function owner and grants MUST be verified
-- on the disposable test project before this draft can be approved.
create function private.has_active_club_role(_role_key text)
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

create function private.can_manage_club_roles()
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

alter table public.user_profiles enable row level security;
alter table public.club_memberships enable row level security;
alter table public.role_assignments enable row level security;
alter table public.audit_events enable row level security;

-- Least-privilege read access only. No client write grants or write policies.
revoke all on table public.user_profiles from anon, authenticated;
revoke all on table public.club_memberships from anon, authenticated;
revoke all on table public.role_assignments from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;
grant select on table public.user_profiles to authenticated;
grant select on table public.club_memberships to authenticated;
grant select on table public.role_assignments to authenticated;
grant select on table public.audit_events to authenticated;

create policy profile_select_active_self_or_chairman
  on public.user_profiles for select to authenticated
  using (
    (user_id = (select auth.uid()) and exists (
      select 1 from public.club_memberships m
      where m.user_id = (select auth.uid()) and m.status = 'active'
    ))
    or (select private.can_manage_club_roles())
  );

create policy membership_select_active_self_or_chairman
  on public.club_memberships for select to authenticated
  using (
    (user_id = (select auth.uid()) and status = 'active')
    or (select private.can_manage_club_roles())
  );

create policy role_assignment_select_active_self_or_chairman
  on public.role_assignments for select to authenticated
  using (
    (exists (
      select 1
      from public.club_memberships m
      where m.id = membership_id
        and m.user_id = (select auth.uid())
        and m.status = 'active'
    ))
    or (select private.can_manage_club_roles())
  );

create policy audit_select_chairman_only
  on public.audit_events for select to authenticated
  using ((select private.can_manage_club_roles()));

-- No INSERT/UPDATE/DELETE policies or grants for authenticated/anon on these tables.
-- Privileged writes must use a separately reviewed trusted server-side workflow.
-- Verify private is NOT in Supabase Data API exposed schemas; SQL cannot configure that.
-- Verify function owner, table grants, RLS, and function grants after execution in test only.

commit;

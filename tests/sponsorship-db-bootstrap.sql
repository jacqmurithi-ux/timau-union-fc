\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema private;
create table auth.users(id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid
$$;
create table private.club_records(
 id uuid primary key default gen_random_uuid(),
 record_type text not null,
 publication_status text not null default 'pending',
 data jsonb not null default '{}'::jsonb
);
create or replace function private.current_club_roles() returns text[] language sql stable as $$
 select string_to_array(coalesce(current_setting('request.test.roles',true),''),',')
$$;
create or replace function private.is_active_platform_admin(_uid uuid) returns boolean language sql stable as $$
 select coalesce(current_setting('request.test.platform_admin',true),'false')='true' and _uid is not null
$$;
grant usage on schema auth,private to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
grant execute on function private.current_club_roles() to authenticated;
grant execute on function private.is_active_platform_admin(uuid) to authenticated;

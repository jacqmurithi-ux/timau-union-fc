-- Apply this adapter to Union Test before the Team Manager workspace migration.
begin;
do $$
declare c record;
begin
 for c in select conname from pg_constraint where conrelid='public.role_assignments'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%role_key%' loop
  execute format('alter table public.role_assignments drop constraint %I',c.conname);
 end loop;
end $$;
alter table public.role_assignments add constraint role_assignments_role_key_check
 check(role_key=any(array['chairman','vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team','player_welfare']::text[]));
create or replace function private.user_has_active_club_role(_user_id uuid,_role text)
returns boolean language sql stable security definer set search_path=''
as $f$
 select exists(select 1 from public.role_assignments ra join public.club_memberships cm on cm.id=ra.membership_id join auth.users u on u.id=cm.user_id
 where cm.user_id=_user_id and cm.status='active' and ra.role_key=_role and ra.revoked_at is null and u.email_confirmed_at is not null)
$f$;
revoke all on function private.user_has_active_club_role(uuid,text) from public,anon,authenticated;
commit;

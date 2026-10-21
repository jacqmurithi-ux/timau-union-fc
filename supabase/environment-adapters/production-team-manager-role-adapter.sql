-- Apply this adapter to Timau Union FC Production before the Team Manager workspace migration.
begin;
do $$
declare c record;
begin
 for c in select conname from pg_constraint where conrelid='private.role_assignments'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%role_key%' loop
  execute format('alter table private.role_assignments drop constraint %I',c.conname);
 end loop;
end $$;
alter table private.role_assignments add constraint role_assignments_role_key_check
 check(role_key=any(array['chairman','vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team','player_welfare']::text[]));
create or replace function private.user_has_active_club_role(_user_id uuid,_role text)
returns boolean language sql stable security definer set search_path=''
as $f$
 select exists(select 1 from private.role_assignments ra join private.account_access aa on aa.user_id=ra.user_id join auth.users u on u.id=ra.user_id
 where ra.user_id=_user_id and ra.role_key=_role and ra.active and aa.status='approved' and u.email_confirmed_at is not null)
$f$;
revoke all on function private.user_has_active_club_role(uuid,text) from public,anon,authenticated;
commit;

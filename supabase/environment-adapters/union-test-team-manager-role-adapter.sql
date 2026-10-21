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

-- Allow the dedicated Player Welfare role in Union Test role assignment.
create or replace function public.club_admin_change_role(_actor uuid,_target_user_id uuid,_role_key text,_action text,_note text default null)
returns text language plpgsql security definer set search_path=''
as $function$
declare v public.club_memberships%rowtype;
begin
 perform private.assert_chairman(_actor);
 if _target_user_id=_actor or _role_key not in('vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team','player_welfare')
    or _action not in('assign','revoke') or length(coalesce(_note,''))>500 then
  raise exception using errcode='22023',message='invalid_role_change';
 end if;
 select * into v from public.club_memberships where user_id=_target_user_id and status='active' for update;
 if not found then raise exception using errcode='P0002',message='active_membership_required'; end if;
 if _action='assign' then
  insert into public.role_assignments(membership_id,role_key,assigned_by,note) values(v.id,_role_key,_actor,nullif(btrim(_note),''));
 else
  update public.role_assignments set revoked_at=clock_timestamp(),revoked_by=_actor,note=coalesce(nullif(btrim(_note),''),note)
  where membership_id=v.id and role_key=_role_key and revoked_at is null;
  if not found then raise exception using errcode='P0002',message='active_role_not_found'; end if;
 end if;
 insert into public.audit_events(actor_user_id,action_key,entity_type,entity_id,details)
 values(_actor,'role_'||_action,'club_membership',v.id::text,jsonb_build_object('role_key',_role_key,'note_present',nullif(btrim(_note),'') is not null));
 return _action||'d';
end;
$function$;

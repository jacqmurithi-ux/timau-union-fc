\set ON_ERROR_STOP on
create role anon nologin;
create role authenticated nologin;
create schema auth;
create schema private;
create table auth.users(id uuid primary key, email text unique, email_confirmed_at timestamptz);
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

create table private.role_assignments(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 role_key text not null, active boolean not null default true, assigned_by uuid,
 assigned_at timestamptz not null default now(), revoked_by uuid, revoked_at timestamptz, reason text
);
create table private.account_access(
 user_id uuid primary key references auth.users(id), status text not null,
 requested_at timestamptz not null default now(), decided_at timestamptz, decided_by uuid,
 decision_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table private.sponsor_user_links(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 sponsor_record_id uuid not null references private.club_records(id), active boolean not null default true,
 linked_by uuid not null, linked_at timestamptz not null default now(), unlinked_by uuid,
 unlinked_at timestamptz, reason text not null
);
create unique index sponsor_user_links_one_active_user on private.sponsor_user_links(user_id) where active;
create table private.sponsor_workspace_audit(
 id bigserial primary key, actor_user_id uuid, record_table text not null, record_id uuid,
 action_key text not null, before_data jsonb, after_data jsonb, reason text, created_at timestamptz not null default now()
);


create or replace function public.sponsor_lead_set_user_link(_user_id uuid, _sponsor_record_id uuid, _link boolean, _reason text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare v_actor uuid:=auth.uid(); v_roles text[]; v_link_id uuid; v_old jsonb; v_new jsonb;
begin
 if v_actor is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead or Platform Admin required' using errcode='42501';
 end if;
 if _user_id is null or _user_id=v_actor then raise exception 'Choose a different sponsor account' using errcode='22023'; end if;
 if length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000 then raise exception 'A reason of 3 to 1000 characters is required' using errcode='22023'; end if;
 select coalesce(array_agg(role_key),array[]::text[]) into v_roles from private.role_assignments where user_id=_user_id and active;
 if not ('sponsor'=any(v_roles)) then raise exception 'Target account must have the Sponsor role' using errcode='22023'; end if;
 if not exists(select 1 from private.account_access aa join auth.users u on u.id=aa.user_id
   where aa.user_id=_user_id and aa.status='approved' and u.email_confirmed_at is not null) then
   raise exception 'Target account must be email-verified and approved' using errcode='22023';
 end if;
 select to_jsonb(l) into v_old from private.sponsor_user_links l where l.user_id=_user_id and l.active for update;
 if not _link then
   if v_old is null then raise exception 'No active sponsor link exists for this user'; end if;
   update private.sponsor_user_links set active=false,unlinked_by=v_actor,unlinked_at=now(),reason=btrim(_reason)
    where user_id=_user_id and active returning id into v_link_id;
   v_new:=jsonb_build_object('active',false,'sponsor_record_id',v_old->>'sponsor_record_id');
 else
   if _sponsor_record_id is null then raise exception 'Choose a sponsor record'; end if;
   if not exists(select 1 from private.club_records c where c.id=_sponsor_record_id and c.record_type='sponsor' and c.publication_status='approved') then
     raise exception 'Sponsor record must be approved before linking'; end if;
   if v_old is not null then
     update private.sponsor_user_links set active=false,unlinked_by=v_actor,unlinked_at=now(),reason=btrim(_reason)
     where user_id=_user_id and active;
   end if;
   insert into private.sponsor_user_links(user_id,sponsor_record_id,active,linked_by,reason)
   values(_user_id,_sponsor_record_id,true,v_actor,btrim(_reason)) returning id into v_link_id;
   v_new:=jsonb_build_object('active',true,'sponsor_record_id',_sponsor_record_id);
 end if;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(v_actor,'sponsor_user_links',v_link_id,
 case when private.is_active_platform_admin(v_actor) then case when _link then 'admin_override_sponsor_user_linked_or_changed' else 'admin_override_sponsor_user_unlinked' end else case when _link then 'sponsor_user_linked_or_changed' else 'sponsor_user_unlinked' end end,
 v_old,v_new,btrim(_reason));
 return jsonb_build_object('ok',true,'link_id',v_link_id,'active',_link,'sponsor_record_id',case when _link then _sponsor_record_id else null end);
end $function$;

create or replace function private.is_active_platform_admin(_uid uuid) returns boolean language sql stable as $$
 select coalesce(current_setting('request.test.platform_admin',true),'false')='true' and _uid is not null
$$;
grant usage on schema auth,private to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
grant execute on function private.current_club_roles() to authenticated;
grant execute on function private.is_active_platform_admin(uuid) to authenticated;

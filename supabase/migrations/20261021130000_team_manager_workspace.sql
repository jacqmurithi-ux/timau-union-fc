-- Team Manager workspace duties, role hardening, and override audit.
-- Review and apply to Union Test first; this migration is not auto-applied.
begin;
create table if not exists private.tm_records(
 id uuid primary key default gen_random_uuid(),
 section_key text not null check(section_key=any(array['squad_admin','match_day','transport_logistics','team_sheet_report','discipline_welfare','communication','training_coordination','reporting']::text[])),
 data jsonb not null check(jsonb_typeof(data)='object'),
 publication_status text not null default 'draft' check(publication_status in('draft','approved','archived')),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 approved_by uuid references auth.users(id), approved_at timestamptz,
 check((publication_status='approved' and approved_by is not null and approved_at is not null) or publication_status<>'approved'));
create index if not exists tm_records_section_updated_idx on private.tm_records(section_key,updated_at desc);
alter table private.tm_records enable row level security;
revoke all on private.tm_records from public,anon,authenticated;
drop policy if exists tm_records_no_direct_access on private.tm_records;
create policy tm_records_no_direct_access on private.tm_records for all to anon,authenticated using(false) with check(false);

create table if not exists private.tm_record_audit(
 id bigint generated always as identity primary key, actor_user_id uuid references auth.users(id) on delete set null,
 record_id uuid, section_key text not null, action_key text not null,
 old_data jsonb not null default '{}'::jsonb check(jsonb_typeof(old_data)='object'),
 new_data jsonb not null default '{}'::jsonb check(jsonb_typeof(new_data)='object'),
 old_status text,new_status text,is_admin_override boolean not null default false,reason text,created_at timestamptz not null default now());
create index if not exists tm_record_audit_record_created_idx on private.tm_record_audit(record_id,created_at desc);
alter table private.tm_record_audit enable row level security;
revoke all on private.tm_record_audit from public,anon,authenticated;
drop policy if exists tm_record_audit_no_direct_access on private.tm_record_audit;
create policy tm_record_audit_no_direct_access on private.tm_record_audit for all to anon,authenticated using(false) with check(false);

create or replace function private.role_can_manage_record(_roles text[],_type text)
returns boolean language sql immutable set search_path=''
as $f$ select coalesce('chairman'=any(_roles) or
 (not ('team_manager'=any(_roles)) and ('secretary'=any(_roles) or (_type='news' and 'media_team'=any(_roles)) or (_type='sponsor' and 'sponsor_lead'=any(_roles)))) or
 (_type in('player','fixture','activity') and _roles && array['team_manager','coach']::text[]),false) $f$;
revoke all on function private.role_can_manage_record(text[],text) from public,anon,authenticated;

create or replace function private.can_manage_club_record(_roles text[],_is_platform_admin boolean,_created_by uuid)
returns boolean language plpgsql stable security definer set search_path=''
as $f$
declare v_tm boolean;
begin
 if coalesce(_is_platform_admin,false) or 'chairman'=any(coalesce(_roles,array[]::text[])) then return true; end if;
 v_tm:=private.user_has_active_club_role(_created_by,'team_manager');
 if v_tm then return 'team_manager'=any(coalesce(_roles,array[]::text[])); end if;
 if 'team_manager'=any(coalesce(_roles,array[]::text[])) then return false; end if;
 return 'secretary'=any(coalesce(_roles,array[]::text[]));
end $f$;
revoke all on function private.can_manage_club_record(text[],boolean,uuid) from public,anon,authenticated;

create or replace function private.valid_tm_record_data(_s text,_d jsonb)
returns boolean language plpgsql immutable set search_path=''
as $f$
declare a text[]; req text; k text;
begin
 if _d is null or jsonb_typeof(_d)<>'object' then return false; end if;
 case _s
 when 'squad_admin' then a:=array['player_name','registration_licensing','contact_availability','notes'];req:='player_name';
 when 'match_day' then a:=array['fixture','checklist','venue_kickoff','notes'];req:='fixture';
 when 'transport_logistics' then a:=array['fixture','trip_plan','fares_per_player','treasurer_submission'];req:='fixture';
 when 'team_sheet_report' then a:=array['fixture','team_list_submission','post_match_report','notes'];req:='fixture';
 when 'discipline_welfare' then a:=array['player_name','case_type_follow_up','restricted_notes','next_action'];req:='player_name';
 when 'communication' then a:=array['audience','notice','sent_at_channel','change_log'];req:='notice';
 when 'training_coordination' then a:=array['session_date','pitch_booking','attendance','notes'];req:='session_date';
 when 'reporting' then a:=array['period','squad_status','results_needs','management_summary'];req:='period';
 else return false; end case;
 if not(_d?req) or jsonb_typeof(_d->req)<>'string' or length(btrim(_d->>req))=0 then return false; end if;
 for k in select jsonb_object_keys(_d) loop if not(k=any(a)) or jsonb_typeof(_d->k)<>'string' or length(_d->>k)>5000 then return false; end if; end loop;
 return true;
end $f$;
revoke all on function private.valid_tm_record_data(text,jsonb) from public,anon,authenticated;

alter table private.club_record_audit add column if not exists old_data jsonb not null default '{}'::jsonb;
alter table private.club_record_audit add column if not exists new_data jsonb not null default '{}'::jsonb;
alter table private.club_record_audit add column if not exists is_admin_override boolean not null default false;
alter table private.club_record_audit add column if not exists old_status text;
alter table private.club_record_audit add column if not exists new_status text;

create or replace function public.club_get_workspace_bundle()
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean; chair boolean; tm boolean; welfare boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles(); chair:='chairman'=any(r);tm:='team_manager'=any(r);welfare:='player_welfare'=any(r);
 if not adm and coalesce(array_length(r,1),0)=0 then raise exception 'Approved active club role required'; end if;
 return jsonb_build_object('roles',to_jsonb(r),'is_platform_admin',adm,'can_approve',adm or coalesce(array_length(r,1),0)>0,
 'records',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'record_type',c.record_type,'data',c.data,'publication_status',c.publication_status,'created_at',c.created_at,'updated_at',c.updated_at,'approved_at',c.approved_at,'can_approve',adm or private.role_can_manage_record(r,c.record_type))
 from private.club_records c where adm or chair or (private.role_can_manage_record(r,c.record_type) and private.can_manage_club_record(r,false,c.created_by))),'[]'::jsonb),
 'tm_records',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'record_type','tm_'||t.section_key,'section_key',t.section_key,'data',t.data,'publication_status',t.publication_status,'created_at',t.created_at,'updated_at',t.updated_at,'approved_at',t.approved_at,'can_approve',adm or chair or tm)
 from private.tm_records t where adm or chair or tm or (welfare and t.section_key='discipline_welfare') or ('treasurer'=any(r) and t.section_key='transport_logistics' and lower(coalesce(t.data->>'treasurer_submission','')) like 'submitted%')),'[]'::jsonb));
end $f$;
revoke all on function public.club_get_workspace_bundle() from public,anon; grant execute on function public.club_get_workspace_bundle() to authenticated;

create or replace function public.club_save_record(_record_id uuid,_record_type text,_data jsonb)
returns uuid language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; id2 uuid; typ text; creator uuid; oldj jsonb; oldst text; override boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 if not private.valid_club_record_data(_record_type,_data) then raise exception 'Invalid record type or field values'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if not adm and coalesce(array_length(r,1),0)=0 then raise exception 'Approved active club role required'; end if;
 if not adm and not private.role_can_manage_record(r,_record_type) then raise exception 'Your role cannot edit this record type'; end if;
 if _record_id is not null then
  select record_type,created_by,data,publication_status into typ,creator,oldj,oldst from private.club_records where id=_record_id for update;
  if not found then raise exception 'Record not found'; end if;
  if not adm and (not private.role_can_manage_record(r,typ) or not private.can_manage_club_record(r,false,creator)) then raise exception 'Your role cannot edit this record'; end if;
  override:=adm or 'chairman'=any(r);
  update private.club_records set record_type=_record_type,data=_data,publication_status='draft',approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now() where id=_record_id returning id into id2;
  insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason,old_data,new_data,is_admin_override,old_status,new_status)
  values(auth.uid(),id2,_record_type,case when override then 'admin_override_updated' else 'record_updated' end,case when override then 'Administrator override; saved as draft' else 'Saved as draft; approval reset' end,oldj,_data,override,oldst,'draft');
 else
  insert into private.club_records(record_type,data,created_by,updated_by) values(_record_type,_data,auth.uid(),auth.uid()) returning id into id2;
  insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,new_data) values(auth.uid(),id2,_record_type,'record_created',_data);
 end if;
 return id2;
end $f$;
revoke all on function public.club_save_record(uuid,text,jsonb) from public,anon;grant execute on function public.club_save_record(uuid,text,jsonb) to authenticated;

create or replace function public.club_set_publication_status(_record_id uuid,_new_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; typ text; creator uuid; d jsonb; oldst text; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if _new_status not in('approved','archived','draft') then raise exception 'Invalid publication status'; end if;
 if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then raise exception 'Reason of 3 to 1000 characters required'; end if;
 select record_type,created_by,data,publication_status into typ,creator,d,oldst from private.club_records where id=_record_id for update;
 if not found then raise exception 'Record not found'; end if;
 if not adm and (not private.role_can_manage_record(r,typ) or not private.can_manage_club_record(r,false,creator)) then raise exception 'Your role cannot change publication status'; end if;
 over:=adm or 'chairman'=any(r);
 update private.club_records set publication_status=_new_status,approved_by=case when _new_status='approved' then auth.uid() else null end,approved_at=case when _new_status='approved' then now() else null end,updated_by=auth.uid(),updated_at=now() where id=_record_id;
 insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason,old_data,new_data,is_admin_override,old_status,new_status)
 values(auth.uid(),_record_id,typ,case when over then 'admin_override_publication_'||_new_status else 'publication_'||_new_status end,btrim(_reason),d,d,over,oldst,_new_status);
 return true;
end $f$;
revoke all on function public.club_set_publication_status(uuid,text,text) from public,anon;grant execute on function public.club_set_publication_status(uuid,text,text) to authenticated;

create or replace function public.tm_save_record(_record_id uuid,_section_key text,_data jsonb,_reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; oldrow private.tm_records%rowtype; id2 uuid; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if not(adm or 'chairman'=any(r) or 'team_manager'=any(r)) then raise exception 'Only TM or administrator can edit TM records'; end if;
 if not private.valid_tm_record_data(_section_key,_data) then raise exception 'Invalid TM section or field values'; end if;
 if _record_id is not null then
  select * into oldrow from private.tm_records where id=_record_id for update;
  if not found then raise exception 'TM record not found'; end if;
  over:=adm or 'chairman'=any(r);
  if over and not('team_manager'=any(r)) and (_reason is null or length(btrim(_reason))<3) then raise exception 'Administrator override reason of at least 3 characters required'; end if;
  update private.tm_records set section_key=_section_key,data=_data,publication_status='draft',approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now() where id=_record_id returning id into id2;
  insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
  values(auth.uid(),id2,_section_key,case when over and not('team_manager'=any(r)) then 'admin_override_updated' else 'record_updated' end,oldrow.data,_data,oldrow.publication_status,'draft',over,case when over then coalesce(nullif(btrim(_reason),''),'Administrator override') else 'Saved as draft; approval reset' end);
 else
  insert into private.tm_records(section_key,data,created_by,updated_by) values(_section_key,_data,auth.uid(),auth.uid()) returning id into id2;
  insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,new_data,new_status) values(auth.uid(),id2,_section_key,'record_created',_data,'draft');
 end if;
 return id2;
end $f$;
revoke all on function public.tm_save_record(uuid,text,jsonb,text) from public,anon;grant execute on function public.tm_save_record(uuid,text,jsonb,text) to authenticated;

create or replace function public.tm_set_publication_status(_record_id uuid,_new_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; oldrow private.tm_records%rowtype; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if not(adm or 'chairman'=any(r) or 'team_manager'=any(r)) then raise exception 'Only TM or administrator can change TM publication status'; end if;
 if _new_status not in('approved','archived','draft') then raise exception 'Invalid publication status'; end if;
 if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then raise exception 'Reason of 3 to 1000 characters required'; end if;
 select * into oldrow from private.tm_records where id=_record_id for update;
 if not found then raise exception 'TM record not found'; end if;
 over:=adm or 'chairman'=any(r);
 update private.tm_records set publication_status=_new_status,approved_by=case when _new_status='approved' then auth.uid() else null end,approved_at=case when _new_status='approved' then now() else null end,updated_by=auth.uid(),updated_at=now() where id=_record_id;
 insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(auth.uid(),_record_id,oldrow.section_key,case when over and not('team_manager'=any(r)) then 'admin_override_publication_'||_new_status else 'publication_'||_new_status end,oldrow.data,oldrow.data,oldrow.publication_status,_new_status,over,btrim(_reason));
 return true;
end $f$;
revoke all on function public.tm_set_publication_status(uuid,text,text) from public,anon;grant execute on function public.tm_set_publication_status(uuid,text,text) to authenticated;

create or replace function public.tm_get_audit(_record_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if not(adm or 'chairman'=any(r) or 'team_manager'=any(r) or 'player_welfare'=any(r)) then raise exception 'Not authorized to view TM audit'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'actor_user_id',a.actor_user_id,'record_id',a.record_id,'section_key',a.section_key,'action_key',a.action_key,'old_data',a.old_data,'new_data',a.new_data,'old_status',a.old_status,'new_status',a.new_status,'is_admin_override',a.is_admin_override,'reason',a.reason,'created_at',a.created_at) order by a.created_at desc)
 from private.tm_record_audit a where (_record_id is null or a.record_id=_record_id)
 and (adm or 'chairman'=any(r) or 'team_manager'=any(r) or ('player_welfare'=any(r) and a.section_key='discipline_welfare'))),'[]'::jsonb);
end $f$;
revoke all on function public.tm_get_audit(uuid) from public,anon;grant execute on function public.tm_get_audit(uuid) to authenticated;
commit;

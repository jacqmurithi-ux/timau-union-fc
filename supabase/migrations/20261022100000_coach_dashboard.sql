-- Coach dashboard records, role isolation, safe squad views, and admin override audit.
-- New coach-owned records always begin as drafts. This migration is reviewed in a feature branch;
-- do not apply to production until the branch/PR has been reviewed.
begin;

create table if not exists private.coach_records (
  id uuid primary key default gen_random_uuid(),
  section_key text not null check (section_key = any(array[
    'training_plans','training_attendance','match_selection','tactics_match_prep',
    'player_performance','match_analysis','player_development'
  ]::text[])),
  data jsonb not null check (jsonb_typeof(data)='object'),
  publication_status text not null default 'draft' check (publication_status in ('draft','approved','archived')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  check ((publication_status='approved' and approved_by is not null and approved_at is not null) or publication_status<>'approved')
);
create index if not exists coach_records_section_updated_idx on private.coach_records(section_key, updated_at desc);
alter table private.coach_records enable row level security;
revoke all on private.coach_records from public, anon, authenticated;
drop policy if exists coach_records_no_direct_access on private.coach_records;
create policy coach_records_no_direct_access on private.coach_records for all to anon, authenticated using(false) with check(false);

-- Reuse the existing audit table created for the Team Manager workspace.
alter table private.tm_record_audit add column if not exists old_data jsonb not null default '{}'::jsonb;
alter table private.tm_record_audit add column if not exists new_data jsonb not null default '{}'::jsonb;
alter table private.tm_record_audit add column if not exists is_admin_override boolean not null default false;
alter table private.tm_record_audit add column if not exists old_status text;
alter table private.tm_record_audit add column if not exists new_status text;
create index if not exists tm_record_audit_coach_idx on private.tm_record_audit(section_key, created_at desc);
revoke all on private.tm_record_audit from public, anon, authenticated;

create or replace function private.valid_coach_record_data(_section text, _data jsonb)
returns boolean language plpgsql immutable set search_path=''
as $f$
declare allowed text[]; required_key text; k text;
begin
 if _data is null or jsonb_typeof(_data)<>'object' then return false; end if;
 case _section
  when 'training_plans' then allowed:=array['week_start','session_date','objectives','drills','duration_minutes','notes']; required_key:='session_date';
  when 'training_attendance' then allowed:=array['session_date','player_name','attendance_status','coach_notes']; required_key:='player_name';
  when 'match_selection' then allowed:=array['fixture','match_date','formation','starting_xi','substitutes','player_roles','coach_notes']; required_key:='fixture';
  when 'tactics_match_prep' then allowed:=array['fixture','opponent_notes','game_plan','set_pieces','notes']; required_key:='fixture';
  when 'player_performance' then allowed:=array['fixture','player_name','rating','goals','assists','minutes_played','strengths','development_areas']; required_key:='player_name';
  when 'match_analysis' then allowed:=array['fixture','match_date','review','worked_well','to_fix','notes']; required_key:='fixture';
  when 'player_development' then allowed:=array['player_name','age_group','targets','progress','next_review_date','notes']; required_key:='player_name';
  else return false;
 end case;
 if not (_data ? required_key) or jsonb_typeof(_data->required_key)<>'string' or length(btrim(_data->>required_key))=0 then return false; end if;
 for k in select jsonb_object_keys(_data) loop
   if not (k=any(allowed)) or jsonb_typeof(_data->k)<>'string' or length(_data->>k)>5000 then return false; end if;
 end loop;
 return true;
end $f$;
revoke all on function private.valid_coach_record_data(text,jsonb) from public,anon,authenticated;

create or replace function public.coach_get_dashboard()
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean; rows jsonb; squad jsonb; fitness jsonb; discipline jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 if not (adm or 'chairman'=any(r) or 'coach'=any(r)) then raise exception 'Coach or administrator access required'; end if;

 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'section_key',c.section_key,'data',c.data,
  'publication_status',c.publication_status,'created_by',c.created_by,'updated_by',c.updated_by,
  'created_at',c.created_at,'updated_at',c.updated_at,'approved_at',c.approved_at,
  'is_admin_override', (c.created_by<>c.updated_by and (adm or 'chairman'=any(r)))
 ) order by c.updated_at desc),'[]'::jsonb) into rows
 from private.coach_records c
 where adm or 'chairman'=any(r) or c.created_by=auth.uid();

 -- Player profiles are read-only. Return only coach-relevant profile fields.
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'data',jsonb_strip_nulls(jsonb_build_object(
  'name',c.data->'name','position',c.data->'position','squad_number',c.data->'squad_number',
  'age_group',c.data->'age_group','availability_status',c.data->'availability_status',
  'fitness_status',c.data->'fitness_status'
 ))) order by coalesce(c.data->>'name','')),'[]'::jsonb) into squad
 from private.club_records c where c.record_type='player' and c.publication_status<>'archived';

 -- Explicit allowlist only; never expose restricted welfare notes to Coach.
 select coalesce(jsonb_agg(jsonb_build_object('player_name',t.data->'player_name',
  'status',coalesce(t.data->>'availability_status',t.data->>'fitness_status'),
  'return_status',t.data->'return_status')),'[]'::jsonb) into fitness
 from private.tm_records t where t.section_key='discipline_welfare'
 and (t.data ? 'availability_status' or t.data ? 'fitness_status');

 select coalesce(jsonb_agg(jsonb_build_object('player_name',t.data->'player_name',
  'cards',t.data->'cards','suspension_status',t.data->'suspension_status',
  'discipline_status',t.data->'discipline_status')),'[]'::jsonb) into discipline
 from private.tm_records t where t.section_key='discipline_welfare'
 and (t.data ? 'cards' or t.data ? 'suspension_status' or t.data ? 'discipline_status');

 return jsonb_build_object('is_admin',adm or 'chairman'=any(r),'roles',to_jsonb(r),
 'records',rows,'squad',squad,'fitness',fitness,'discipline',discipline);
end $f$;
revoke all on function public.coach_get_dashboard() from public, anon;
grant execute on function public.coach_get_dashboard() to authenticated;

create or replace function public.coach_save_record(_record_id uuid, _section_key text, _data jsonb, _reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; oldrow private.coach_records%rowtype; new_id uuid; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 over:=adm or 'chairman'=any(r);
 if not (over or 'coach'=any(r)) then raise exception 'Only Coach or administrator can manage Coach records'; end if;
 if not private.valid_coach_record_data(_section_key,_data) then raise exception 'Invalid Coach record fields'; end if;
 if _record_id is not null then
  select * into oldrow from private.coach_records where id=_record_id for update;
  if not found then raise exception 'Coach record not found'; end if;
  if not over and oldrow.created_by<>auth.uid() then raise exception 'Coach can only edit own records'; end if;
  if over and not ('coach'=any(r)) and (_reason is null or length(btrim(_reason))<3 or length(_reason)>1000) then
    raise exception 'Administrator override reason of 3 to 1000 characters required';
  end if;
  update private.coach_records set section_key=_section_key,data=_data,publication_status='draft',
    approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now()
    where id=_record_id returning id into new_id;
  insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,old_data,new_data,
    old_status,new_status,is_admin_override,reason)
  values(auth.uid(),new_id,'coach_'||_section_key,
    case when over and not ('coach'=any(r)) then 'admin_override_updated' else 'record_updated' end,
    oldrow.data,_data,oldrow.publication_status,'draft',over,
    case when over and not ('coach'=any(r)) then btrim(_reason) else 'Saved as draft; approval reset' end);
 else
  insert into private.coach_records(section_key,data,created_by,updated_by)
   values(_section_key,_data,auth.uid(),auth.uid()) returning id into new_id;
  insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,new_data,new_status,is_admin_override,reason)
   values(auth.uid(),new_id,'coach_'||_section_key,'record_created',_data,'draft',false,'Coach draft created');
 end if;
 return new_id;
end $f$;
revoke all on function public.coach_save_record(uuid,text,jsonb,text) from public,anon;
grant execute on function public.coach_save_record(uuid,text,jsonb,text) to authenticated;

create or replace function public.coach_set_publication_status(_record_id uuid,_new_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; oldrow private.coach_records%rowtype; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 over:=adm or 'chairman'=any(r);
 if not over then raise exception 'Only Chairman or Platform Admin can approve or change Coach publication status'; end if;
 if _new_status not in ('approved','draft','archived') then raise exception 'Invalid publication status'; end if;
 if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then raise exception 'Reason of 3 to 1000 characters required'; end if;
 select * into oldrow from private.coach_records where id=_record_id for update;
 if not found then raise exception 'Coach record not found'; end if;
 update private.coach_records set publication_status=_new_status,
  approved_by=case when _new_status='approved' then auth.uid() else null end,
  approved_at=case when _new_status='approved' then now() else null end,
  updated_by=auth.uid(),updated_at=now() where id=_record_id;
 insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,old_data,new_data,
  old_status,new_status,is_admin_override,reason)
 values(auth.uid(),_record_id,'coach_'||oldrow.section_key,'admin_override_publication_'||_new_status,
  oldrow.data,oldrow.data,oldrow.publication_status,_new_status,true,btrim(_reason));
 return true;
end $f$;
revoke all on function public.coach_set_publication_status(uuid,text,text) from public,anon;
grant execute on function public.coach_set_publication_status(uuid,text,text) to authenticated;

commit;

-- Add structured TM-owned squad, fitness, return and discipline fields for Coach read-only views.
-- This migration is for review/testing; it is not applied to production by this change.
begin;

create or replace function private.valid_tm_record_data(_s text,_d jsonb)
returns boolean language plpgsql immutable set search_path=''
as $f$
declare a text[]; req text; k text;
begin
 if _d is null or jsonb_typeof(_d)<>'object' then return false; end if;
 case _s
 when 'squad_admin' then a:=array['player_name','registration_licensing','position','age_group','availability_status','fitness_status','contact_availability','notes'];req:='player_name';
 when 'match_day' then a:=array['fixture','checklist','venue_kickoff','notes'];req:='fixture';
 when 'transport_logistics' then a:=array['fixture','trip_plan','fares_per_player','treasurer_submission'];req:='fixture';
 when 'team_sheet_report' then a:=array['fixture','team_list_submission','post_match_report','notes'];req:='fixture';
 when 'discipline_welfare' then a:=array['player_name','case_type_follow_up','availability_status','fitness_status','return_status','cards','suspension_status','restricted_notes','next_action'];req:='player_name';
 when 'communication' then a:=array['audience','notice','sent_at_channel','change_log'];req:='notice';
 when 'training_coordination' then a:=array['session_date','pitch_booking','attendance','notes'];req:='session_date';
 when 'reporting' then a:=array['period','squad_status','results_needs','management_summary'];req:='period';
 else return false; end case;
 if not(_d?req) or jsonb_typeof(_d->req)<>'string' or length(btrim(_d->>req))=0 then return false; end if;
 for k in select jsonb_object_keys(_d) loop
  if not(k=any(a)) or jsonb_typeof(_d->k)<>'string' or length(_d->>k)>5000 then return false; end if;
 end loop;
 return true;
end $f$;
revoke all on function private.valid_tm_record_data(text,jsonb) from public,anon,authenticated;

-- Coach dashboard reads structured status fields from TM-owned private records only.
create or replace function public.coach_get_dashboard()
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean; rows jsonb; squad jsonb; fitness jsonb; discipline jsonb; fixtures jsonb; activities jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 if not (adm or 'chairman'=any(r) or 'coach'=any(r)) then raise exception 'Coach or administrator access required'; end if;

 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'section_key',c.section_key,'data',c.data,
  'publication_status',c.publication_status,'created_by',c.created_by,'updated_by',c.updated_by,
  'created_at',c.created_at,'updated_at',c.updated_at,'approved_at',c.approved_at,
  'is_admin_override',(c.created_by<>c.updated_by and (adm or 'chairman'=any(r)))
 ) order by c.updated_at desc),'[]'::jsonb) into rows
 from private.coach_records c where adm or 'chairman'=any(r) or c.created_by=auth.uid();

 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'data',jsonb_strip_nulls(jsonb_build_object(
  'name',t.data->'player_name','position',t.data->'position','age_group',t.data->'age_group',
  'availability_status',t.data->'availability_status','fitness_status',t.data->'fitness_status'
 ))) order by coalesce(t.data->>'player_name','')),'[]'::jsonb) into squad
 from private.tm_records t where t.section_key='squad_admin' and t.publication_status<>'archived';

 select coalesce(jsonb_agg(jsonb_build_object('player_name',t.data->'player_name',
  'availability_status',t.data->'availability_status','fitness_status',t.data->'fitness_status',
  'return_status',t.data->'return_status')),'[]'::jsonb) into fitness
 from private.tm_records t where t.section_key='discipline_welfare'
 and (t.data ? 'availability_status' or t.data ? 'fitness_status' or t.data ? 'return_status');

 select coalesce(jsonb_agg(jsonb_build_object('player_name',t.data->'player_name',
  'cards',t.data->'cards','suspension_status',t.data->'suspension_status')),'[]'::jsonb) into discipline
 from private.tm_records t where t.section_key='discipline_welfare'
 and (t.data ? 'cards' or t.data ? 'suspension_status');

 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'data',c.data,'publication_status',c.publication_status)),'[]'::jsonb)
 into fixtures from private.club_records c where c.record_type='fixture' and c.publication_status<>'archived';
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'data',c.data,'publication_status',c.publication_status)),'[]'::jsonb)
 into activities from private.club_records c where c.record_type='activity' and c.publication_status<>'archived';

 return jsonb_build_object('is_admin',adm or 'chairman'=any(r),'roles',to_jsonb(r),'records',rows,
 'squad',squad,'fitness',fitness,'discipline',discipline,'fixtures',fixtures,'activities',activities);
end $f$;
revoke all on function public.coach_get_dashboard() from public,anon;
grant execute on function public.coach_get_dashboard() to authenticated;
commit;

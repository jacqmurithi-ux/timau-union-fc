-- Secretary workspace expansion. Review and apply only after Union Test verification.
begin;

create table if not exists private.secretary_records (
  id uuid primary key default gen_random_uuid(),
  section_key text not null check (section_key = any (array[
    'meeting','correspondence','registration','membership','document','notice','election','report'
  ]::text[])),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  publication_status text not null default 'draft' check (publication_status in ('draft','approved','archived')),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists secretary_records_section_status_idx
  on private.secretary_records(section_key, publication_status, updated_at desc);
alter table private.secretary_records enable row level security;
revoke all on private.secretary_records from public, anon, authenticated;
drop policy if exists secretary_records_no_direct_access on private.secretary_records;
create policy secretary_records_no_direct_access on private.secretary_records
  for all to anon, authenticated using (false) with check (false);

-- Reuse private.tm_record_audit, the existing append-only audit table used by role workspaces.
create index if not exists tm_record_audit_secretary_lookup_idx on private.tm_record_audit(section_key,record_id,created_at desc);

create or replace function private.secretary_actor_can_manage()
returns boolean language sql stable security definer set search_path=''
as $$
 select auth.uid() is not null and (
   private.is_active_platform_admin(auth.uid()) or
   'chairman' = any(private.current_club_roles()) or
   'secretary' = any(private.current_club_roles())
 )
$$;
revoke all on function private.secretary_actor_can_manage() from public, anon;
grant execute on function private.secretary_actor_can_manage() to authenticated;

create or replace function public.secretary_get_workspace()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare r text[]; adm boolean; secretary boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required' using errcode='42501'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid());
 secretary:=coalesce('secretary'=any(r),false);
 if not (adm or 'chairman'=any(r) or secretary) then raise exception 'Secretary workspace access required' using errcode='42501'; end if;
 return jsonb_build_object(
  'roles',to_jsonb(coalesce(r,array[]::text[])), 'is_admin',adm,
  'records',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'section_key',s.section_key,'data',s.data,'publication_status',s.publication_status,
    'created_by',s.created_by,'updated_by',s.updated_by,'approved_by',s.approved_by,
    'approved_at',s.approved_at,'created_at',s.created_at,'updated_at',s.updated_at)
    order by s.updated_at desc)
    from private.secretary_records s
    where (adm or 'chairman'=any(r) or secretary)
      and (s.section_key not in ('registration','membership') or adm or 'chairman'=any(r) or secretary)
  ),'[]'::jsonb),
  'finance_summary',case when adm or 'chairman'=any(r) or secretary then
   jsonb_build_object(
    'income_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger where entry_type='income'),0),
    'expenses_kes',coalesce(-(select sum(amount_kes) from private.club_financial_ledger where entry_type='expense'),0)
      -coalesce((select sum(amount_kes) from private.club_financial_ledger where entry_type='expense_reversal'),0),
    'balance_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger),0),
    'pending_requisitions',coalesce((select count(*) from private.treasurer_records where record_type='requisition' and submitted_by=auth.uid() and status in ('pending','queried')),0)
   ) else null end,
  'own_requisitions',coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'title',f.title,'amount_kes',f.amount_kes,
     'status',f.status,'review_reason',f.review_reason,'created_at',f.created_at)
     order by f.created_at desc) from private.treasurer_records f
     where f.record_type='requisition' and f.submitted_by=auth.uid()),'[]'::jsonb)
 );
end $$;
revoke all on function public.secretary_get_workspace() from public, anon;
grant execute on function public.secretary_get_workspace() to authenticated;

create or replace function public.secretary_save_record(_id uuid, _section_key text, _data jsonb)
returns uuid language plpgsql security definer set search_path=''
as $$
declare adm boolean; sec boolean; old private.secretary_records%rowtype; rid uuid;
begin
 if auth.uid() is null then raise exception 'Sign-in required' using errcode='42501'; end if;
 adm:=private.is_active_platform_admin(auth.uid());
 sec:='secretary'=any(private.current_club_roles());
 if not (adm or 'chairman'=any(private.current_club_roles()) or sec) then raise exception 'Secretary or admin required' using errcode='42501'; end if;
 if _section_key not in ('meeting','correspondence','registration','membership','document','notice','election','report') then raise exception 'Unsupported Secretary record type'; end if;
 if jsonb_typeof(coalesce(_data,'{}'::jsonb))<>'object' then raise exception 'Record data must be an object'; end if;
 if length(btrim(coalesce(_data->>'title',_data->>'name',_data->>'subject',''))) < 2 then raise exception 'A title, name or subject is required'; end if;
 if _id is null then
  insert into private.secretary_records(section_key,data,publication_status,created_by,updated_by)
  values(_section_key,_data,'draft',auth.uid(),auth.uid()) returning id into rid;
  insert into private.tm_record_audit(record_id,section_key,actor_user_id,action_key,new_data,new_status,is_admin_override)
  values(rid,_section_key,auth.uid(),'record_created',_data,'draft',adm or 'chairman'=any(private.current_club_roles()));
 else
  select * into old from private.secretary_records where id=_id for update;
  if not found then raise exception 'Secretary record not found'; end if;
  if not (adm or 'chairman'=any(private.current_club_roles()) or sec) then
   raise exception 'Only the Secretary who created this record or an admin may edit it' using errcode='42501';
  end if;
  if old.publication_status='approved' and not (adm or 'chairman'=any(private.current_club_roles())) then
   raise exception 'Approved records require admin override; create a correction draft instead' using errcode='42501';
  end if;
  update private.secretary_records set section_key=_section_key,data=_data,publication_status='draft',
    approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now() where id=_id;
  rid:=_id;
  insert into private.tm_record_audit(record_id,section_key,actor_user_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
  values(rid,_section_key,auth.uid(),'record_updated',old.data,_data,old.publication_status,'draft',adm or 'chairman'=any(private.current_club_roles()),
    case when adm or 'chairman'=any(private.current_club_roles()) then 'Admin/Chairman override; changes saved as draft' else null end);
 end if;
 return rid;
end $$;
revoke all on function public.secretary_save_record(uuid,text,jsonb) from public, anon;
grant execute on function public.secretary_save_record(uuid,text,jsonb) to authenticated;

create or replace function public.secretary_set_status(_id uuid,_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare adm boolean; sec boolean; old private.secretary_records%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign-in required' using errcode='42501'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); sec:='secretary'=any(private.current_club_roles());
 if not (adm or 'chairman'=any(private.current_club_roles()) or sec) then raise exception 'Secretary or admin required' using errcode='42501'; end if;
 if _status not in ('approved','draft','archived') or length(btrim(coalesce(_reason,'')))<3 then raise exception 'Valid status and reason required'; end if;
 select * into old from private.secretary_records where id=_id for update;
 if not found then raise exception 'Secretary record not found'; end if;
 if not (adm or 'chairman'=any(private.current_club_roles()) or (sec and old.created_by=auth.uid())) then raise exception 'Not permitted to review this record' using errcode='42501'; end if;
 if _status='approved' and not (adm or 'chairman'=any(private.current_club_roles())) then
  raise exception 'Secretary records must be approved by Chairman or admin' using errcode='42501';
 end if;
 update private.secretary_records set publication_status=_status,
  approved_by=case when _status='approved' then auth.uid() else null end,
  approved_at=case when _status='approved' then now() else null end,
  updated_by=auth.uid(),updated_at=now() where id=_id;
 insert into private.tm_record_audit(record_id,section_key,actor_user_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(old.id,old.section_key,auth.uid(),'publication_'||_status,old.data,old.data,old.publication_status,_status,adm or 'chairman'=any(private.current_club_roles()),btrim(_reason));
 return true;
end $$;
revoke all on function public.secretary_set_status(uuid,text,text) from public, anon;
grant execute on function public.secretary_set_status(uuid,text,text) to authenticated;

-- A Secretary must never create/edit expense or ledger records. Requisition submissions
-- continue only through the existing treasurer_submit_requisition RPC and own records
-- remain scoped in treasurer_get_dashboard/secretary_get_workspace.
-- Add a private, non-destructive likely-duplicate matcher for player approval/import review.
create or replace function private.secretary_edit_distance(a text,b text)
returns integer language plpgsql immutable set search_path=''
as $$
declare i integer; j integer; ca integer; cb integer; prev integer[]; curr integer[]; cost integer; n integer; m integer;
begin
 a:=lower(regexp_replace(coalesce(a,''),'[^a-z0-9]','','g'));
 b:=lower(regexp_replace(coalesce(b,''),'[^a-z0-9]','','g'));
 n:=length(a); m:=length(b);
 if n=0 then return m; end if; if m=0 then return n; end if;
 prev:=array(select generate_series(0,m));
 for i in 1..n loop
  curr:=array_fill(0,array[m+1]); curr[1]:=i;
  for j in 1..m loop
   cost:=case when substr(a,i,1)=substr(b,j,1) then 0 else 1 end;
   curr[j+1]:=least(curr[j]+1,prev[j+1]+1,prev[j]+cost);
  end loop;
  prev:=curr;
 end loop;
 return prev[m+1];
end $$;
revoke all on function private.secretary_edit_distance(text,text) from public,anon,authenticated;

create or replace function public.secretary_find_player_duplicates(_name text,_date_of_birth date default null,_fkf_number text default null)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare adm boolean; r text[]; result jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required' using errcode='42501'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid());
 if not (adm or 'chairman'=any(r) or 'secretary'=any(r) or 'team_manager'=any(r)) then raise exception 'Player register access required' using errcode='42501'; end if;
 if length(btrim(coalesce(_name,'')))<2 then raise exception 'Player name is required'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.data->>'name','date_of_birth',p.data->>'date_of_birth','fkf_number',p.data->>'fkf_number','status',p.publication_status,'score',
  case when nullif(_fkf_number,'') is not null and p.data->>'fkf_number'=_fkf_number then 1.0
       when _date_of_birth is not null and (p.data->>'date_of_birth')::date=_date_of_birth then 0.95
       else greatest(0.0,1.0-(private.secretary_edit_distance(_name,p.data->>'name')::numeric/greatest(length(_name),length(p.data->>'name'),1))) end)
  order by p.created_at desc),'[]'::jsonb)
 into result from private.club_records p where p.record_type='player'
 and ( (nullif(_fkf_number,'') is not null and p.data->>'fkf_number'=_fkf_number)
   or (_date_of_birth is not null and p.data->>'date_of_birth' is not null and (p.data->>'date_of_birth')::date=_date_of_birth)
   or (private.secretary_edit_distance(_name,p.data->>'name') <= greatest(1,ceil(length(_name)*0.22)::int)
        ));
 return result;
end $$;
revoke all on function public.secretary_find_player_duplicates(text,date,text) from public,anon;
grant execute on function public.secretary_find_player_duplicates(text,date,text) to authenticated;

create or replace function public.secretary_merge_player_records(_keep_id uuid,_duplicate_id uuid,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; keep private.club_records%rowtype; dup private.club_records%rowtype; merged jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid());
 if not (adm or 'chairman'=any(r) or 'secretary'=any(r) or 'team_manager'=any(r)) then raise exception 'Secretary or authorized player-register manager required'; end if;
 if _keep_id=_duplicate_id or length(btrim(coalesce(_reason,'')))<3 then raise exception 'Choose two different records and provide a reason'; end if;
 select * into keep from private.club_records where id=_keep_id and record_type='player' for update;
 select * into dup from private.club_records where id=_duplicate_id and record_type='player' for update;
 if keep.id is null or dup.id is null then raise exception 'Both player records must exist'; end if;
 merged:=dup.data||keep.data;
 update private.club_records set data=merged,publication_status='draft',approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now() where id=keep.id;
 update private.club_records set publication_status='archived',updated_by=auth.uid(),updated_at=now() where id=dup.id;
 insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason)
 values(auth.uid(),keep.id,'player','duplicate_merge_kept',btrim(_reason)),(auth.uid(),dup.id,'player','duplicate_merge_archived_into_'||keep.id::text,btrim(_reason));
 insert into private.tm_record_audit(record_id,section_key,actor_user_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(keep.id,'membership',auth.uid(),'player_duplicate_merge',jsonb_build_object('data',keep.data),jsonb_build_object('data',merged,'duplicate_id',dup.id),keep.publication_status,'draft',adm or 'chairman'=any(r),btrim(_reason));
 return true;
end $$;
revoke all on function public.secretary_merge_player_records(uuid,uuid,text) from public,anon;
grant execute on function public.secretary_merge_player_records(uuid,uuid,text) to authenticated;

-- Private supporting documents (IDs and under-18 consent forms) are never public.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('secretary-restricted-documents','secretary-restricted-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists secretary_restricted_docs_select on storage.objects;
create policy secretary_restricted_docs_select on storage.objects for select to authenticated
using (bucket_id='secretary-restricted-documents' and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())));
drop policy if exists secretary_restricted_docs_insert on storage.objects;
create policy secretary_restricted_docs_insert on storage.objects for insert to authenticated
with check (bucket_id='secretary-restricted-documents' and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())) and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists secretary_restricted_docs_update on storage.objects;
create policy secretary_restricted_docs_update on storage.objects for update to authenticated
using (bucket_id='secretary-restricted-documents' and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())))
with check (bucket_id='secretary-restricted-documents' and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())));
drop policy if exists secretary_restricted_docs_delete on storage.objects;
create policy secretary_restricted_docs_delete on storage.objects for delete to authenticated
using (bucket_id='secretary-restricted-documents' and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())));


create or replace function public.secretary_log_duplicate_decision(_record_id uuid,_match_id uuid,_resolution text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; p private.club_records%rowtype; m private.club_records%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid());
 if not (adm or 'chairman'=any(r) or 'secretary'=any(r) or 'team_manager'=any(r)) then raise exception 'Player register access required'; end if;
 if _resolution not in ('not_duplicate') or length(btrim(coalesce(_reason,'')))<3 then raise exception 'Resolution and reason required'; end if;
 select * into p from private.club_records where id=_record_id and record_type='player';
 if not found then raise exception 'Player record not found'; end if;
 if _match_id is not null then
  select * into m from private.club_records where id=_match_id and record_type='player';
  if not found then raise exception 'Matching player record not found'; end if;
 end if;
 insert into private.tm_record_audit(record_id,section_key,actor_user_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(_record_id,'membership',auth.uid(),'player_duplicate_marked_not_duplicate',
  jsonb_build_object('name',p.data->>'name','matched_record_id',_match_id),
  jsonb_build_object('resolution',_resolution,'match_name',m.data->>'name'),p.publication_status,p.publication_status,adm or 'chairman'=any(r),btrim(_reason));
 return true;
end $$;
revoke all on function public.secretary_log_duplicate_decision(uuid,uuid,text,text) from public,anon;
grant execute on function public.secretary_log_duplicate_decision(uuid,uuid,text,text) to authenticated;

-- Keep the Treasurer as the only reader of the detailed ledger/opening balance
-- through the Treasurer dashboard. Secretary sees approved reports and own requisitions only.
create or replace function public.treasurer_get_dashboard()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare r text[]; adm boolean; chair boolean; treas boolean; uid uuid;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 uid:=auth.uid(); adm:=private.is_active_platform_admin(uid); r:=private.current_club_roles();
 chair:=coalesce('chairman'=any(r),false); treas:=coalesce('treasurer'=any(r),false);
 if not (adm or chair or treas or 'secretary'=any(r) or 'vice_chairman'=any(r) or 'sponsor'=any(r) or 'sponsor_lead'=any(r) or 'team_manager'=any(r) or 'coach'=any(r) or 'player'=any(r) or 'player_welfare'=any(r)) then raise exception 'Active club role required'; end if;
 return jsonb_build_object(
  'roles',to_jsonb(coalesce(r,array[]::text[])),'is_admin',adm,'can_manage',treas,'can_override',adm or chair,
  'transport_plans',case when adm or chair or treas then coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'data',t.data,'created_by',t.created_by,'created_at',t.created_at,'treasurer_status',t.treasurer_status,'treasurer_review_reason',t.treasurer_review_reason) order by t.created_at desc) from private.tm_records t where t.section_key='transport_logistics' and t.treasurer_status in('pending','queried','rejected')),'[]'::jsonb) else '[]'::jsonb end,
  'records',coalesce((select jsonb_agg(jsonb_build_object(
    'id',f.id,'record_type',f.record_type,'title',f.title,'amount_kes',f.amount_kes::text,'record_date',f.record_date,'category',f.category,'source',f.source,'receipt_reference',f.receipt_reference,
    'payload',f.payload,'status',f.status,'created_by',f.created_by,'submitted_by',f.submitted_by,'sponsor_user_id',f.sponsor_user_id,'reviewed_by',f.reviewed_by,'reviewed_at',f.reviewed_at,
    'review_reason',f.review_reason,'created_at',f.created_at,'published_at',f.published_at)
    order by f.created_at desc) from private.treasurer_records f
    where (adm or chair or treas or ('sponsor'=any(r) and f.sponsor_user_id=uid)
      or (r && array['secretary','vice_chairman']::text[] and f.record_type='financial_report' and f.status in('approved','published'))
      or (f.record_type='requisition' and f.submitted_by=uid))), '[]'::jsonb),
  'opening_balance',case when adm or chair or treas then (select to_jsonb(o) from private.treasurer_opening_balance o where o.id=true) else null end,
  'ledger',case when adm or chair or treas then coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'entry_type',l.entry_type,'amount_kes',l.amount_kes::text,'description',l.description,'record_id',coalesce(l.source_treasurer_record_id,l.source_expense_id),'created_at',l.created_at) order by l.created_at desc) from (select * from private.club_financial_ledger order by created_at desc limit 100) l),'[]'::jsonb) else '[]'::jsonb end,
  'audit',case when adm or chair or treas then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'record_id',a.treasurer_record_id,'actor_user_id',a.actor_user_id,'action_key',a.action_key,'old_data',a.old_data,'new_data',a.new_data,'reason',a.reason,'is_admin_override',a.is_admin_override,'created_at',a.created_at) order by a.created_at desc) from (select * from private.club_financial_audit order by created_at desc limit 100) a),'[]'::jsonb) else '[]'::jsonb end
 );
end $$;
revoke all on function public.treasurer_get_dashboard() from public,anon;
grant execute on function public.treasurer_get_dashboard() to authenticated;


-- Database-side duplicate gate: the UI warning is helpful, but direct RPC calls
-- must also resolve every likely player-name match before approval.
create or replace function public.club_set_publication_status(_record_id uuid,_new_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_is_admin boolean; v_type text; v_data jsonb; v_updated timestamptz; match_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 v_is_admin:=private.is_active_platform_admin(auth.uid());
 if _new_status not in('approved','archived','draft') then raise exception 'Invalid publication status'; end if;
 if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then raise exception 'Reason of 3 to 1000 characters required'; end if;
 select record_type,data,updated_at into v_type,v_data,v_updated from private.club_records where id=_record_id for update;
 if not found then raise exception 'Record not found'; end if;
 if not v_is_admin and not private.role_can_manage_record(private.current_club_roles(),v_type) then raise exception 'Your role cannot approve or change publication status for this record type'; end if;
 if _new_status='approved' and v_type='player' then
  select p.id into match_id from private.club_records p
  where p.record_type='player' and p.id<>_record_id and p.publication_status<>'archived'
   and private.secretary_edit_distance(coalesce(v_data->>'name',''),coalesce(p.data->>'name','')) <= greatest(1,ceil(length(coalesce(v_data->>'name',''))*0.22)::int)
   and length(coalesce(p.data->>'name',''))>1
   and not exists(select 1 from private.tm_record_audit a
     where a.record_id=_record_id and a.action_key='player_duplicate_marked_not_duplicate'
       and a.old_data->>'matched_record_id'=p.id::text and a.created_at>=v_updated)
  order by p.created_at desc limit 1;
  if match_id is not null then
   raise exception 'Likely duplicate player detected (record %). Review matching records and merge, mark not duplicate with a reason, or cancel before approval.',match_id using errcode='23514';
  end if;
 end if;
 update private.club_records set publication_status=_new_status,approved_by=case when _new_status='approved' then auth.uid() else null end,
  approved_at=case when _new_status='approved' then now() else null end,updated_by=auth.uid(),updated_at=now() where id=_record_id;
 insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason)
 values(auth.uid(),_record_id,v_type,'publication_'||_new_status,btrim(_reason));
 return true;
end $function$;
revoke all on function public.club_set_publication_status(uuid,text,text) from public,anon;
grant execute on function public.club_set_publication_status(uuid,text,text) to authenticated;


-- Remove the old broad Secretary finance read path. The Secretary gets aggregate
-- totals through club_get_financial_summary and own requisitions through the
-- Treasurer dashboard, never item-level expense or ledger rows.
create or replace function public.tm_get_expenses()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare r text[]; adm boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 if not (adm or r && array['chairman','treasurer']::text[]) then
  raise exception 'Expense record access is restricted to Chairman, Treasurer, or Platform Admin' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',e.id,'record_type','tm_expenses','data',jsonb_build_object('category',e.category,'description',e.description,
   'amount_kes',e.amount_kes::text,'expense_date',e.expense_date::text,'squad_number',e.squad_number),
   'status',e.status,'publication_status',e.status,'created_by',e.created_by,'updated_by',e.updated_by,
   'reviewed_by',e.reviewed_by,'reviewed_at',e.reviewed_at,'review_reason',e.review_reason,
   'created_at',e.created_at,'updated_at',e.updated_at,'can_review',adm or 'chairman'=any(r) or 'treasurer'=any(r))
   order by e.created_at desc) from private.club_financial_expenses e),'[]'::jsonb);
end $function$;
revoke all on function public.tm_get_expenses() from public,anon;
grant execute on function public.tm_get_expenses() to authenticated;

create or replace function public.club_get_financial_summary()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare r text[]; adm boolean; chair boolean; treas boolean; sec boolean; summary jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 chair:=coalesce('chairman'=any(r),false); treas:=coalesce('treasurer'=any(r),false); sec:=coalesce('secretary'=any(r),false);
 if not (adm or chair or sec or treas) then raise exception 'Finance summary access required' using errcode='42501'; end if;
 summary:=jsonb_build_object(
  'currency','KES',
  'approved_income_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger where entry_type='income'),0),
  'approved_expenses_kes',coalesce(-(select sum(amount_kes) from private.club_financial_ledger where entry_type in('expense','expense_reversal','adjustment')),0),
  'balance_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger),0),
  'pending_expenses_count',(select count(*) from private.club_financial_expenses where status='pending'),
  'pending_expenses_kes',coalesce((select sum(amount_kes) from private.club_financial_expenses where status='pending'),0)
 );
 if adm or chair or treas then
  summary:=summary||jsonb_build_object('ledger',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'entry_type',l.entry_type,'amount_kes',l.amount_kes,'description',l.description,'created_at',l.created_at,'approved_by',l.approved_by) order by l.created_at desc) from (select * from private.club_financial_ledger order by created_at desc limit 25) l),'[]'::jsonb));
 else
  summary:=summary||jsonb_build_object('ledger','[]'::jsonb);
 end if;
 return summary;
end $function$;
revoke all on function public.club_get_financial_summary() from public,anon;
grant execute on function public.club_get_financial_summary() to authenticated;


-- General official documents remain private to signed-in club officials; only
-- Secretary/Chairman/Admin may write them. Identity/under-18 documents use the
-- separate stricter bucket above.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('secretary-official-documents','secretary-official-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists secretary_official_docs_select on storage.objects;
create policy secretary_official_docs_select on storage.objects for select to authenticated
using (bucket_id='secretary-official-documents' and
 (private.is_active_platform_admin(auth.uid()) or cardinality(private.current_club_roles())>0));
drop policy if exists secretary_official_docs_insert on storage.objects;
create policy secretary_official_docs_insert on storage.objects for insert to authenticated
with check (bucket_id='secretary-official-documents' and
 (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles()))
 and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists secretary_official_docs_update on storage.objects;
create policy secretary_official_docs_update on storage.objects for update to authenticated
using (bucket_id='secretary-official-documents' and
 (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())))
with check (bucket_id='secretary-official-documents' and
 (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())));
drop policy if exists secretary_official_docs_delete on storage.objects;
create policy secretary_official_docs_delete on storage.objects for delete to authenticated
using (bucket_id='secretary-official-documents' and
 (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'secretary'=any(private.current_club_roles())));

commit;

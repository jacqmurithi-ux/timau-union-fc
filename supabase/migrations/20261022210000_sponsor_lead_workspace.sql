-- Sponsor Lead workspace expansion. Candidate migration only; review and apply to Union Test first.
begin;

create table if not exists private.sponsor_prospects (
 id uuid primary key default gen_random_uuid(),
 sponsor_name text not null check(length(btrim(sponsor_name)) between 2 and 240),
 stage text not null default 'identified' check(stage in ('identified','contacted','meeting','proposal_sent','negotiating','won','declined')),
 contact_person text, phone text, email text, next_follow_up date, notes text not null default '',
 publication_status text not null default 'draft' check(publication_status in ('draft','approved','archived')),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_packages (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 2 and 160),
 tier text not null check(tier in ('kit','match_day','training','website_social','community_partner','other')),
 benefits text not null default '', price_kes numeric(14,2) check(price_kes is null or price_kes>=0),
 in_kind_value text, duration text not null default '', status text not null default 'draft' check(status in ('draft','approved','archived')),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_agreements (
 id uuid primary key default gen_random_uuid(), sponsor_record_id uuid references private.club_records(id) on delete set null,
 sponsor_name text not null, package_id uuid references private.sponsor_packages(id) on delete set null,
 start_date date, end_date date, amount_kes numeric(14,2) check(amount_kes is null or amount_kes>=0),
 in_kind_value text, payment_schedule text not null default '', obligations text not null default '',
 signed_document_path text, status text not null default 'draft' check(status in ('draft','active','expired','renewal_pending','closed')),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(end_date is null or start_date is null or end_date>=start_date)
);
create table if not exists private.sponsor_contributions (
 id uuid primary key default gen_random_uuid(), agreement_id uuid references private.sponsor_agreements(id) on delete set null,
 sponsor_name text not null, contribution_kind text not null check(contribution_kind in ('cash','in_kind')),
 pledged_amount_kes numeric(14,2) check(pledged_amount_kes is null or pledged_amount_kes>=0),
 in_kind_description text, pledged_on date not null default current_date,
 receipt_status text not null default 'pledged' check(receipt_status in ('pledged','part_received','received','cancelled')),
 received_amount_kes numeric(14,2) not null default 0 check(received_amount_kes>=0),
 treasurer_confirmed_by uuid references auth.users(id), treasurer_confirmed_at timestamptz,
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(contribution_kind<>'cash' or pledged_amount_kes is not null),
 check(receipt_status not in ('received','part_received') or treasurer_confirmed_by is not null)
);
create table if not exists private.sponsor_benefit_delivery (
 id uuid primary key default gen_random_uuid(), agreement_id uuid references private.sponsor_agreements(id) on delete cascade,
 sponsor_name text not null, benefit_key text not null check(benefit_key in ('logo_on_kit','match_banner','social_posts','match_announcements','other')),
 description text not null, is_done boolean not null default false, proof_url text,
 completed_at timestamptz, completed_by uuid references auth.users(id),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_communications (
 id uuid primary key default gen_random_uuid(), sponsor_name text not null,
 communication_type text not null check(communication_type in ('call','meeting','email','follow_up','other')),
 occurred_on date not null default current_date, summary text not null, next_step text, next_step_date date,
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_role_requests (
 id uuid primary key default gen_random_uuid(), sponsor_name text, target_role text not null check(target_role in ('media_team','secretary')),
 request_type text not null check(request_type in ('sponsor_post_or_graphic','letter_or_document')),
 title text not null, details text not null default '', status text not null default 'draft' check(status in ('draft','submitted','in_progress','completed','declined')),
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_workspace_audit (
 id bigint generated always as identity primary key, actor_user_id uuid references auth.users(id) on delete set null,
 record_table text not null, record_id uuid, action_key text not null, before_data jsonb, after_data jsonb,
 reason text, created_at timestamptz not null default now()
);

do $$
declare t text;
begin
 foreach t in array array['sponsor_prospects','sponsor_packages','sponsor_agreements','sponsor_contributions','sponsor_benefit_delivery','sponsor_communications','sponsor_role_requests','sponsor_workspace_audit'] loop
  execute format('alter table private.%I enable row level security',t);
  execute format('revoke all on private.%I from public, anon, authenticated',t);
 end loop;
end $$;

-- Private signed documents: never use a public bucket or expose paths on public pages.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('sponsor-agreements','sponsor-agreements',false,15000000,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false, file_size_limit=15000000, allowed_mime_types=array['application/pdf','image/jpeg','image/png'];

create or replace function private.can_access_sponsor_workspace(_area text)
returns boolean language plpgsql stable security definer set search_path=''
as $$
declare r text[]; admin boolean;
begin
 if auth.uid() is null then return false; end if;
 admin:=private.is_active_platform_admin(auth.uid());
 r:=private.current_club_roles();
 if admin or 'chairman'=any(r) then return true; end if;
 if _area='finance' then return 'treasurer'=any(r); end if;
 if _area='media_requests' then return 'media_team'=any(r); end if;
 if _area='secretary_requests' then return 'secretary'=any(r); end if;
 return 'sponsor_lead'=any(r);
end $$;
revoke all on function private.can_access_sponsor_workspace(text) from public,anon,authenticated;

create or replace function private.sponsor_workspace_guard()
returns trigger language plpgsql security definer set search_path=''
as $$
declare admin boolean; r text[]; before_j jsonb; after_j jsonb; record_key uuid; table_key text;
begin
 admin:=private.is_active_platform_admin(auth.uid());
 r:=private.current_club_roles();
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if tg_table_name='sponsor_contributions' then
   if tg_op='UPDATE' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r) or 'treasurer'=any(r)) then
     raise exception 'Not authorized to update sponsor contribution';
   end if;
   if tg_op='INSERT' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then raise exception 'Sponsor Lead or admin required'; end if;
   if tg_op='UPDATE' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r) or 'treasurer'=any(r)) then raise exception 'Not authorized'; end if;
   if tg_op='UPDATE' and (new.receipt_status is distinct from old.receipt_status or new.received_amount_kes is distinct from old.received_amount_kes or new.treasurer_confirmed_by is distinct from old.treasurer_confirmed_by or new.treasurer_confirmed_at is distinct from old.treasurer_confirmed_at) and not (admin or 'treasurer'=any(r)) then raise exception 'Only Treasurer or admin can confirm received money'; end if;
 end if;
 if tg_table_name<>'sponsor_contributions' and not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then
   if tg_table_name='sponsor_role_requests' and tg_op='UPDATE' and ((new.status is distinct from old.status) and (('media_team'=any(r) and old.target_role='media_team') or ('secretary'=any(r) and old.target_role='secretary'))) then
     null;
   else raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 end if;
 if tg_op='INSERT' then before_j:=null; after_j:=to_jsonb(new); record_key:=new.id;
 elsif tg_op='UPDATE' then before_j:=to_jsonb(old); after_j:=to_jsonb(new); record_key:=new.id;
 else before_j:=to_jsonb(old); after_j:=null; record_key:=old.id; end if;
 table_key:=tg_table_name;
 if admin and tg_op='UPDATE' and before_j is distinct from after_j then
  insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
  values(auth.uid(),table_key,record_key,'admin_override',before_j,after_j,'Administrative override');
 end if;
 if tg_op='DELETE' then return old; end if;
 new.updated_by:=auth.uid(); new.updated_at:=now(); return new;
end $$;
revoke all on function private.sponsor_workspace_guard() from public,anon,authenticated;

do $$
declare t text;
begin
 foreach t in array array['sponsor_prospects','sponsor_packages','sponsor_agreements','sponsor_contributions','sponsor_benefit_delivery','sponsor_communications','sponsor_role_requests'] loop
  execute format('drop trigger if exists sponsor_workspace_guard on private.%I',t);
  execute format('create trigger sponsor_workspace_guard before insert or update or delete on private.%I for each row execute function private.sponsor_workspace_guard()',t);
 end loop;
end $$;

-- Read policies. Direct table privileges stay revoked; access is through authenticated RPCs.
create or replace function public.sponsor_lead_get_workspace()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; lead boolean; treasurer boolean; media boolean; secretary boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 lead:=admin or 'chairman'=any(r) or 'sponsor_lead'=any(r);
 treasurer:=admin or 'chairman'=any(r) or 'treasurer'=any(r);
 media:=admin or 'chairman'=any(r) or 'media_team'=any(r);
 secretary:=admin or 'chairman'=any(r) or 'secretary'=any(r);
 if not (lead or treasurer or media or secretary) then raise exception 'Approved club role required'; end if;
 return jsonb_build_object(
  'is_admin',admin,'roles',to_jsonb(r),
  'prospects',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.updated_at desc) from private.sponsor_prospects x),'[]'::jsonb) else '[]'::jsonb end,
  'packages',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.name) from private.sponsor_packages x),'[]'::jsonb) else '[]'::jsonb end,
  'agreements',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.end_date nulls last) from private.sponsor_agreements x),'[]'::jsonb) when treasurer then coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'sponsor_name',a.sponsor_name,'start_date',a.start_date,'end_date',a.end_date,'amount_kes',a.amount_kes,'payment_schedule',a.payment_schedule,'status',a.status) order by a.end_date nulls last) from private.sponsor_agreements a),'[]'::jsonb) else '[]'::jsonb end,
  'contributions',case when lead or treasurer then coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'sponsor_name',c.sponsor_name,'contribution_kind',c.contribution_kind,'pledged_amount_kes',c.pledged_amount_kes,'in_kind_description',c.in_kind_description,'receipt_status',c.receipt_status,'received_amount_kes',c.received_amount_kes,'treasurer_confirmed_at',c.treasurer_confirmed_at) order by c.created_at desc) from private.sponsor_contributions c),'[]'::jsonb) else '[]'::jsonb end,
  'benefits',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.sponsor_name) from private.sponsor_benefit_delivery x),'[]'::jsonb) else '[]'::jsonb end,
  'communications',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.occurred_on desc) from private.sponsor_communications x),'[]'::jsonb) else '[]'::jsonb end,
  'requests',case when lead then coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from private.sponsor_role_requests x),'[]'::jsonb) else coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from private.sponsor_role_requests x where (media and target_role='media_team') or (secretary and target_role='secretary')),'[]'::jsonb) end,
  'audit',case when admin then coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc) from private.sponsor_workspace_audit a),'[]'::jsonb) else '[]'::jsonb end
 );
end $$;
revoke all on function public.sponsor_lead_get_workspace() from public,anon;
grant execute on function public.sponsor_lead_get_workspace() to authenticated;

create or replace function public.sponsor_lead_save_record(_table text,_id uuid,_data jsonb,_reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; lead boolean; result_id uuid; old_j jsonb; new_j jsonb; cols text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid()); lead:=admin or 'chairman'=any(r) or 'sponsor_lead'=any(r);
 if not lead then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if _table not in ('sponsor_prospects','sponsor_packages','sponsor_agreements','sponsor_contributions','sponsor_benefit_delivery','sponsor_communications','sponsor_role_requests') then raise exception 'Unsupported sponsor table'; end if;
 if _data is null or jsonb_typeof(_data)<>'object' then raise exception 'Expected JSON object'; end if;
 if admin and _id is not null and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Admin override reason required'; end if;
 if _table='sponsor_contributions' and _id is not null and not (admin or 'treasurer'=any(r)) then
   if _data ?| array['receipt_status','received_amount_kes','treasurer_confirmed_by','treasurer_confirmed_at'] then raise exception 'Sponsor Lead cannot confirm receipts'; end if;
 end if;
 -- Dynamic SQL is restricted to an allowlisted table and explicit JSON keys.
 if _id is null then
  if _table='sponsor_prospects' then insert into private.sponsor_prospects(sponsor_name,stage,contact_person,phone,email,next_follow_up,notes,created_by,updated_by) values(_data->>'sponsor_name',coalesce(_data->>'stage','identified'),_data->>'contact_person',_data->>'phone',_data->>'email',nullif(_data->>'next_follow_up','')::date,coalesce(_data->>'notes',''),auth.uid(),auth.uid()) returning id into result_id;
  elsif _table='sponsor_packages' then insert into private.sponsor_packages(name,tier,benefits,price_kes,in_kind_value,duration,created_by,updated_by) values(_data->>'name',_data->>'tier',coalesce(_data->>'benefits',''),nullif(_data->>'price_kes','')::numeric,_data->>'in_kind_value',coalesce(_data->>'duration',''),auth.uid(),auth.uid()) returning id into result_id;
  elsif _table='sponsor_agreements' then insert into private.sponsor_agreements(sponsor_record_id,sponsor_name,package_id,start_date,end_date,amount_kes,in_kind_value,payment_schedule,obligations,signed_document_path,created_by,updated_by) values(nullif(_data->>'sponsor_record_id','')::uuid,_data->>'sponsor_name',nullif(_data->>'package_id','')::uuid,nullif(_data->>'start_date','')::date,nullif(_data->>'end_date','')::date,nullif(_data->>'amount_kes','')::numeric,_data->>'in_kind_value',coalesce(_data->>'payment_schedule',''),coalesce(_data->>'obligations',''),_data->>'signed_document_path',auth.uid(),auth.uid()) returning id into result_id;
  elsif _table='sponsor_contributions' then insert into private.sponsor_contributions(agreement_id,sponsor_name,contribution_kind,pledged_amount_kes,in_kind_description,created_by,updated_by) values(nullif(_data->>'agreement_id','')::uuid,_data->>'sponsor_name',_data->>'contribution_kind',nullif(_data->>'pledged_amount_kes','')::numeric,_data->>'in_kind_description',auth.uid(),auth.uid()) returning id into result_id;
  elsif _table='sponsor_benefit_delivery' then insert into private.sponsor_benefit_delivery(agreement_id,sponsor_name,benefit_key,description,is_done,proof_url,completed_at,completed_by,created_by,updated_by) values(nullif(_data->>'agreement_id','')::uuid,_data->>'sponsor_name',_data->>'benefit_key',_data->>'description',coalesce((_data->>'is_done')::boolean,false),_data->>'proof_url',case when coalesce((_data->>'is_done')::boolean,false) then now() end,case when coalesce((_data->>'is_done')::boolean,false) then auth.uid() end,auth.uid(),auth.uid()) returning id into result_id;
  elsif _table='sponsor_communications' then insert into private.sponsor_communications(sponsor_name,communication_type,occurred_on,summary,next_step,next_step_date,created_by,updated_by) values(_data->>'sponsor_name',_data->>'communication_type',coalesce(nullif(_data->>'occurred_on','')::date,current_date),_data->>'summary',_data->>'next_step',nullif(_data->>'next_step_date','')::date,auth.uid(),auth.uid()) returning id into result_id;
  else insert into private.sponsor_role_requests(sponsor_name,target_role,request_type,title,details,created_by,updated_by) values(_data->>'sponsor_name',_data->>'target_role',_data->>'request_type',_data->>'title',coalesce(_data->>'details',''),auth.uid(),auth.uid()) returning id into result_id; end if;
  insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data) values(auth.uid(),_table,result_id,'created',_data);
 else
  -- Updates use the same allowlisted columns, with role and record ownership checked in SQL.
  if _table='sponsor_prospects' then select to_jsonb(x) into old_j from private.sponsor_prospects x where id=_id for update; update private.sponsor_prospects set sponsor_name=coalesce(_data->>'sponsor_name',sponsor_name),stage=coalesce(_data->>'stage',stage),contact_person=coalesce(_data->>'contact_person',contact_person),phone=coalesce(_data->>'phone',phone),email=coalesce(_data->>'email',email),next_follow_up=case when _data ? 'next_follow_up' then nullif(_data->>'next_follow_up','')::date else next_follow_up end,notes=coalesce(_data->>'notes',notes) where id=_id returning to_jsonb(sponsor_prospects),id into new_j,result_id;
  elsif _table='sponsor_packages' then select to_jsonb(x) into old_j from private.sponsor_packages x where id=_id for update; update private.sponsor_packages set name=coalesce(_data->>'name',name),tier=coalesce(_data->>'tier',tier),benefits=coalesce(_data->>'benefits',benefits),price_kes=case when _data ? 'price_kes' then nullif(_data->>'price_kes','')::numeric else price_kes end,in_kind_value=case when _data ? 'in_kind_value' then _data->>'in_kind_value' else in_kind_value end,duration=coalesce(_data->>'duration',duration) where id=_id returning to_jsonb(sponsor_packages),id into new_j,result_id;
  elsif _table='sponsor_agreements' then select to_jsonb(x) into old_j from private.sponsor_agreements x where id=_id for update; update private.sponsor_agreements set sponsor_name=coalesce(_data->>'sponsor_name',sponsor_name),package_id=case when _data ? 'package_id' then nullif(_data->>'package_id','')::uuid else package_id end,start_date=case when _data ? 'start_date' then nullif(_data->>'start_date','')::date else start_date end,end_date=case when _data ? 'end_date' then nullif(_data->>'end_date','')::date else end_date end,amount_kes=case when _data ? 'amount_kes' then nullif(_data->>'amount_kes','')::numeric else amount_kes end,in_kind_value=case when _data ? 'in_kind_value' then _data->>'in_kind_value' else in_kind_value end,payment_schedule=coalesce(_data->>'payment_schedule',payment_schedule),obligations=coalesce(_data->>'obligations',obligations),signed_document_path=case when _data ? 'signed_document_path' then _data->>'signed_document_path' else signed_document_path end where id=_id returning to_jsonb(sponsor_agreements),id into new_j,result_id;
  elsif _table='sponsor_contributions' then select to_jsonb(x) into old_j from private.sponsor_contributions x where id=_id for update; update private.sponsor_contributions set sponsor_name=coalesce(_data->>'sponsor_name',sponsor_name),contribution_kind=coalesce(_data->>'contribution_kind',contribution_kind),pledged_amount_kes=case when _data ? 'pledged_amount_kes' then nullif(_data->>'pledged_amount_kes','')::numeric else pledged_amount_kes end,in_kind_description=case when _data ? 'in_kind_description' then _data->>'in_kind_description' else in_kind_description end where id=_id returning to_jsonb(sponsor_contributions),id into new_j,result_id;
  elsif _table='sponsor_benefit_delivery' then select to_jsonb(x) into old_j from private.sponsor_benefit_delivery x where id=_id for update; update private.sponsor_benefit_delivery set sponsor_name=coalesce(_data->>'sponsor_name',sponsor_name),benefit_key=coalesce(_data->>'benefit_key',benefit_key),description=coalesce(_data->>'description',description),is_done=coalesce((_data->>'is_done')::boolean,is_done),proof_url=case when _data ? 'proof_url' then _data->>'proof_url' else proof_url end,completed_at=case when coalesce((_data->>'is_done')::boolean,is_done) then coalesce(completed_at,now()) else null end,completed_by=case when coalesce((_data->>'is_done')::boolean,is_done) then coalesce(completed_by,auth.uid()) else null end where id=_id returning to_jsonb(sponsor_benefit_delivery),id into new_j,result_id;
  elsif _table='sponsor_communications' then select to_jsonb(x) into old_j from private.sponsor_communications x where id=_id for update; update private.sponsor_communications set sponsor_name=coalesce(_data->>'sponsor_name',sponsor_name),communication_type=coalesce(_data->>'communication_type',communication_type),occurred_on=coalesce(nullif(_data->>'occurred_on','')::date,occurred_on),summary=coalesce(_data->>'summary',summary),next_step=case when _data ? 'next_step' then _data->>'next_step' else next_step end,next_step_date=case when _data ? 'next_step_date' then nullif(_data->>'next_step_date','')::date else next_step_date end where id=_id returning to_jsonb(sponsor_communications),id into new_j,result_id;
  else select to_jsonb(x) into old_j from private.sponsor_role_requests x where id=_id for update; update private.sponsor_role_requests set sponsor_name=case when _data ? 'sponsor_name' then _data->>'sponsor_name' else sponsor_name end,target_role=coalesce(_data->>'target_role',target_role),request_type=coalesce(_data->>'request_type',request_type),title=coalesce(_data->>'title',title),details=coalesce(_data->>'details',details),status=coalesce(_data->>'status',status) where id=_id returning to_jsonb(sponsor_role_requests),id into new_j,result_id; end if;
  if result_id is null then raise exception 'Record not found'; end if;
  insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason) values(auth.uid(),_table,_id,case when admin then 'admin_override' else 'updated' end,old_j,new_j,nullif(btrim(_reason),''));
 end if;
 return result_id;
end $$;
revoke all on function public.sponsor_lead_save_record(text,uuid,jsonb,text) from public,anon;
grant execute on function public.sponsor_lead_save_record(text,uuid,jsonb,text) to authenticated;

create or replace function public.sponsor_lead_confirm_receipt(_contribution_id uuid,_received_amount_kes numeric,_status text)
returns void language plpgsql security definer set search_path=''
as $$
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'treasurer'=any(private.current_club_roles())) then raise exception 'Treasurer or admin required'; end if;
 if _received_amount_kes<0 or _status not in ('pledged','part_received','received','cancelled') then raise exception 'Invalid receipt details'; end if;
 update private.sponsor_contributions set received_amount_kes=_received_amount_kes,receipt_status=_status,treasurer_confirmed_by=auth.uid(),treasurer_confirmed_at=now(),updated_by=auth.uid(),updated_at=now() where id=_contribution_id;
 if not found then raise exception 'Contribution not found'; end if;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data) values(auth.uid(),'sponsor_contributions',_contribution_id,'treasurer_receipt_confirmed',jsonb_build_object('received_amount_kes',_received_amount_kes,'receipt_status',_status));
end $$;
revoke all on function public.sponsor_lead_confirm_receipt(uuid,numeric,text) from public,anon;
grant execute on function public.sponsor_lead_confirm_receipt(uuid,numeric,text) to authenticated;

create or replace function public.sponsor_lead_create_agreement_upload_url(_agreement_id uuid)
returns text language plpgsql security definer set search_path=''
as $$ begin
 if auth.uid() is null or not private.can_access_sponsor_workspace('lead') then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if not exists(select 1 from private.sponsor_agreements where id=_agreement_id) then raise exception 'Agreement not found'; end if;
 return _agreement_id::text;
end $$;
revoke all on function public.sponsor_lead_create_agreement_upload_url(uuid) from public,anon;
grant execute on function public.sponsor_lead_create_agreement_upload_url(uuid) to authenticated;

create or replace function private.can_access_sponsor_agreement(_agreement_id uuid)
returns boolean language sql stable security definer set search_path=''
as $ select auth.uid() is not null and private.can_access_sponsor_workspace('lead') and exists(select 1 from private.sponsor_agreements a where a.id=_agreement_id) $;
revoke all on function private.can_access_sponsor_agreement(uuid) from public,anon,authenticated;
create policy "sponsor agreements private upload" on storage.objects for insert to authenticated with check(bucket_id='sponsor-agreements' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}

commit;
 and private.can_access_sponsor_agreement(((storage.foldername(name))[1])::uuid));
create policy "sponsor agreements private read" on storage.objects for select to authenticated using(bucket_id='sponsor-agreements' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}

commit;
 and private.can_access_sponsor_agreement(((storage.foldername(name))[1])::uuid));
create policy "sponsor agreements private update" on storage.objects for update to authenticated using(bucket_id='sponsor-agreements' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}

commit;
 and private.can_access_sponsor_agreement(((storage.foldername(name))[1])::uuid)) with check(bucket_id='sponsor-agreements' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}

commit;
 and private.can_access_sponsor_agreement(((storage.foldername(name))[1])::uuid));
create policy "sponsor agreements private delete" on storage.objects for delete to authenticated using(bucket_id='sponsor-agreements' and (storage.foldername(name))[1] ~* '^[0-9a-f-]{36}

commit;
 and private.can_access_sponsor_agreement(((storage.foldername(name))[1])::uuid));

commit;

-- Treasurer workspace expansion: financial records, opening-balance lock, requisitions,
-- budgets, sponsor/member contributions, receipt metadata and audit trail.
begin;

alter table private.tm_records add column if not exists treasurer_status text not null default 'pending';
alter table private.tm_records add column if not exists treasurer_reviewed_by uuid references auth.users(id);
alter table private.tm_records add column if not exists treasurer_reviewed_at timestamptz;
alter table private.tm_records add column if not exists treasurer_review_reason text;
alter table private.tm_records drop constraint if exists tm_records_treasurer_status_check;
alter table private.tm_records add constraint tm_records_treasurer_status_check check(treasurer_status in ('pending','approved','rejected','queried'));

create table if not exists private.treasurer_records (
 id uuid primary key default gen_random_uuid(),
 record_type text not null check (record_type in
 ('income','expense','transport_approval','budget','requisition','sponsor_fund','member_contribution','receipt','financial_report','opening_balance')),
 title text not null check(length(btrim(title)) between 2 and 240),
 amount_kes numeric(14,2) not null default 0 check(amount_kes >= 0 and amount_kes <= 100000000000),
 record_date date,
 category text,
 source text,
 receipt_reference text,
 payload jsonb not null default '{}'::jsonb check(jsonb_typeof(payload)='object'),
 status text not null default 'draft' check(status in ('draft','pending','approved','rejected','queried','published','locked')),
 created_by uuid not null references auth.users(id),
 updated_by uuid not null references auth.users(id),
 submitted_by uuid references auth.users(id),
 sponsor_user_id uuid references auth.users(id),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_reason text,
 published_at timestamptz,
 linked_record_id uuid references private.treasurer_records(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists treasurer_records_type_status_date_idx on private.treasurer_records(record_type,status,record_date desc);
create index if not exists treasurer_records_submitter_idx on private.treasurer_records(submitted_by,created_at desc);
create index if not exists treasurer_records_sponsor_idx on private.treasurer_records(sponsor_user_id,record_type);
alter table private.treasurer_records enable row level security;
revoke all on private.treasurer_records from public, anon, authenticated;
drop policy if exists treasurer_records_no_direct_access on private.treasurer_records;
create policy treasurer_records_no_direct_access on private.treasurer_records for all to anon,authenticated using(false) with check(false);

create table if not exists private.treasurer_opening_balance (
 id boolean primary key default true check(id),
 amount_kes numeric(14,2) not null check(amount_kes >= 0 and amount_kes <= 100000000000),
 note text not null check(length(btrim(note)) between 3 and 1000),
 treasurer_confirmed_by uuid references auth.users(id),
 treasurer_confirmed_at timestamptz,
 chairman_confirmed_by uuid references auth.users(id),
 chairman_confirmed_at timestamptz,
 locked_at timestamptz,
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 check((treasurer_confirmed_by is null)=(treasurer_confirmed_at is null)),
 check((chairman_confirmed_by is null)=(chairman_confirmed_at is null))
);
alter table private.treasurer_opening_balance enable row level security;
revoke all on private.treasurer_opening_balance from public,anon,authenticated;
drop policy if exists treasurer_opening_balance_no_direct_access on private.treasurer_opening_balance;
create policy treasurer_opening_balance_no_direct_access on private.treasurer_opening_balance for all to anon,authenticated using(false) with check(false);

-- Reuse the existing canonical ledger and finance audit tables; extend them with
-- links to the expanded Treasurer records rather than creating parallel ledgers.
alter table private.club_financial_ledger enable row level security;
revoke all on private.club_financial_ledger from public,anon,authenticated;
alter table private.club_financial_audit enable row level security;
revoke all on private.club_financial_audit from public,anon,authenticated;
alter table private.club_financial_ledger add column if not exists source_treasurer_record_id uuid references private.treasurer_records(id);
alter table private.club_financial_ledger alter column amount_kes type numeric(14,2);
alter table private.club_financial_ledger drop constraint if exists club_financial_ledger_entry_type_check;
alter table private.club_financial_ledger add constraint club_financial_ledger_entry_type_check
 check(entry_type in('income','expense','expense_reversal','adjustment','opening_balance'));
create index if not exists club_financial_ledger_treasurer_record_idx on private.club_financial_ledger(source_treasurer_record_id);
alter table private.club_financial_audit add column if not exists treasurer_record_id uuid references private.treasurer_records(id);

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
    'id',f.id,'record_type',f.record_type,'title',f.title,'amount_kes',f.amount_kes::text,
    'record_date',f.record_date,'category',f.category,'source',f.source,'receipt_reference',f.receipt_reference,
    'payload',f.payload,'status',f.status,'created_by',f.created_by,'submitted_by',f.submitted_by,
    'sponsor_user_id',f.sponsor_user_id,'reviewed_by',f.reviewed_by,'reviewed_at',f.reviewed_at,
    'review_reason',f.review_reason,'created_at',f.created_at,'published_at',f.published_at)
    order by f.created_at desc)
    from private.treasurer_records f
    where (adm or chair or treas or ('sponsor'=any(r) and f.sponsor_user_id=uid)
      or (r && array['secretary','vice_chairman']::text[] and f.record_type='financial_report' and f.status in('approved','published'))
      or (f.record_type='requisition' and f.submitted_by=uid))), '[]'::jsonb),
  'opening_balance',case when adm or chair or treas or 'secretary'=any(r) then (select to_jsonb(o) from private.treasurer_opening_balance o where o.id=true) else null end,
  'ledger',case when adm or chair or treas or 'secretary'=any(r) then
   coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'entry_type',l.entry_type,'amount_kes',l.amount_kes::text,'description',l.description,'record_id',coalesce(l.source_treasurer_record_id,l.source_expense_id),'created_at',l.created_at) order by l.created_at desc) from (select * from private.club_financial_ledger order by created_at desc limit 100) l),'[]'::jsonb)
   else '[]'::jsonb end,
  'audit',case when adm or chair or treas then
   coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'record_id',a.treasurer_record_id,'actor_user_id',a.actor_user_id,'action_key',a.action_key,'old_data',a.old_data,'new_data',a.new_data,'reason',a.reason,'is_admin_override',a.is_admin_override,'created_at',a.created_at) order by a.created_at desc) from (select * from private.club_financial_audit order by created_at desc limit 100) a),'[]'::jsonb)
   else '[]'::jsonb end);
end $$;
revoke all on function public.treasurer_get_dashboard() from public,anon;
grant execute on function public.treasurer_get_dashboard() to authenticated;

create or replace function public.treasurer_save_record(_id uuid,_record_type text,_title text,_amount_kes numeric,_record_date date,_category text,_source text,_receipt_reference text,_payload jsonb default '{}'::jsonb,_sponsor_user_id uuid default null,_reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; treas boolean; chair boolean; old private.treasurer_records%rowtype; rid uuid; oldj jsonb; newj jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid()); treas:=coalesce('treasurer'=any(r),false); chair:=coalesce('chairman'=any(r),false);
 if _id is null and not treas then raise exception 'Only the Treasurer may create finance records'; end if;
 if _id is not null and not treas then raise exception 'Only the Treasurer may edit finance records; Chairman/Admin may override decisions only'; end if;
 if _record_type not in('income','expense','transport_approval','budget','sponsor_fund','member_contribution','receipt','financial_report') then raise exception 'Unsupported Treasurer record type'; end if;
 if length(btrim(coalesce(_title,'')))<2 or _amount_kes is null or _amount_kes<0 or _amount_kes>100000000000 or coalesce(jsonb_typeof(_payload),'object')<>'object' then raise exception 'Valid title, non-negative KES amount and object details are required'; end if;
 newj:=jsonb_build_object('record_type',_record_type,'title',btrim(_title),'amount_kes',_amount_kes::text,'record_date',_record_date,'category',_category,'source',_source,'receipt_reference',_receipt_reference,'payload',coalesce(_payload,'{}'::jsonb),'sponsor_user_id',_sponsor_user_id);
 if _id is null then
  insert into private.treasurer_records(record_type,title,amount_kes,record_date,category,source,receipt_reference,payload,status,created_by,updated_by,sponsor_user_id)
  values(_record_type,btrim(_title),_amount_kes,_record_date,nullif(_category,''),nullif(_source,''),nullif(_receipt_reference,''),coalesce(_payload,'{}'::jsonb),'draft',auth.uid(),auth.uid(),_sponsor_user_id) returning id into rid;
  insert into private.club_financial_audit(actor_user_id,treasurer_record_id,action_key,new_data) values(auth.uid(),rid,'finance_record_created_as_draft',newj);
 else
  select * into old from private.treasurer_records where id=_id for update;
  if not found then raise exception 'Finance record not found'; end if;
  if old.status='approved' then raise exception 'Approved finance records are immutable; create a separately reviewed adjustment or reversal'; end if;
  
  oldj:=jsonb_build_object('record_type',old.record_type,'title',old.title,'amount_kes',old.amount_kes::text,'record_date',old.record_date,'category',old.category,'source',old.source,'receipt_reference',old.receipt_reference,'payload',old.payload,'status',old.status,'sponsor_user_id',old.sponsor_user_id);
  update private.treasurer_records set record_type=_record_type,title=btrim(_title),amount_kes=_amount_kes,record_date=_record_date,category=nullif(_category,''),source=nullif(_source,''),receipt_reference=nullif(_receipt_reference,''),payload=coalesce(_payload,'{}'::jsonb),sponsor_user_id=_sponsor_user_id,status='draft',updated_by=auth.uid(),updated_at=now(),reviewed_by=null,reviewed_at=null,review_reason=null,published_at=null where id=_id returning id into rid;
  insert into private.club_financial_audit(actor_user_id,treasurer_record_id,action_key,old_data,new_data,reason,is_admin_override)
  values(auth.uid(),rid,'finance_record_edited_as_draft',oldj,newj,nullif(btrim(_reason),''),false);
 end if;
 return rid;
end $$;
revoke all on function public.treasurer_save_record(uuid,text,text,numeric,date,text,text,text,jsonb,uuid,text) from public,anon;
grant execute on function public.treasurer_save_record(uuid,text,text,numeric,date,text,text,text,jsonb,uuid,text) to authenticated;

create or replace function public.treasurer_submit_requisition(_title text,_amount_kes numeric,_category text,_purpose text,_receipt_reference text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; rid uuid;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid());
 if not(adm or coalesce(r,array[]::text[]) && array['team_manager','coach','secretary','vice_chairman','media_team','sponsor_lead','player_welfare']::text[]) then raise exception 'Only Team Manager, Coach or an authorised club official may submit a requisition'; end if;
 if length(btrim(coalesce(_title,'')))<3 or _amount_kes is null or _amount_kes<=0 or _amount_kes>100000000000 or length(btrim(coalesce(_purpose,'')))<3 then raise exception 'Title, positive amount and purpose are required'; end if;
 insert into private.treasurer_records(record_type,title,amount_kes,category,receipt_reference,payload,status,created_by,updated_by,submitted_by)
 values('requisition',btrim(_title),_amount_kes,nullif(_category,''),nullif(_receipt_reference,''),jsonb_build_object('purpose',btrim(_purpose)),'pending',auth.uid(),auth.uid(),auth.uid()) returning id into rid;
 insert into private.club_financial_audit(actor_user_id,treasurer_record_id,action_key,new_data) values(auth.uid(),rid,'requisition_submitted',jsonb_build_object('title',_title,'amount_kes',_amount_kes::text,'category',_category,'purpose',_purpose));
 return rid;
end $$;
revoke all on function public.treasurer_submit_requisition(text,numeric,text,text,text) from public,anon;
grant execute on function public.treasurer_submit_requisition(text,numeric,text,text,text) to authenticated;

create or replace function public.treasurer_review_record(_id uuid,_decision text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; treas boolean; chair boolean; old private.treasurer_records%rowtype; ledger_type text; amount numeric;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(auth.uid()); treas:=coalesce('treasurer'=any(r),false); chair:=coalesce('chairman'=any(r),false);
 if not(adm or treas or chair) then raise exception 'Treasurer, Chairman or Platform Admin required'; end if;
 if _decision not in('approved','rejected','queried','published') or length(btrim(coalesce(_reason,'')))<3 then raise exception 'Decision and reason (minimum 3 characters) required'; end if;
 select * into old from private.treasurer_records where id=_id for update;
 if not found then raise exception 'Record not found'; end if;
 if old.record_type='requisition' and not(adm or treas or chair) then raise exception 'Cannot review requisition'; end if;
 if old.status='approved' then raise exception 'Approved finance records are immutable; create a separately reviewed adjustment or reversal'; end if;
 if _decision='published' and old.record_type<>'financial_report' then raise exception 'Only financial reports may be published'; end if;
 if old.status='pending' and old.submitted_by=auth.uid() then raise exception 'Cannot approve your own requisition'; end if;
 update private.treasurer_records set status=_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=btrim(_reason),published_at=case when _decision='published' then now() else null end,updated_by=auth.uid(),updated_at=now() where id=_id;
 if _decision='approved' and old.status<>'approved' then
  if old.record_type='income' then ledger_type:='income'; amount:=old.amount_kes;
  elsif old.record_type='sponsor_fund' and lower(coalesce(old.category,''))='received' then ledger_type:='income'; amount:=old.amount_kes;
  elsif old.record_type='member_contribution' and lower(coalesce(old.category,'')) in('paid','received') then ledger_type:='income'; amount:=old.amount_kes;
  elsif old.record_type='expense' or old.record_type='transport_approval' then ledger_type:='expense'; amount:=-old.amount_kes;
  end if;
  if ledger_type is not null and amount<>0 then
   insert into private.club_financial_ledger(entry_type,amount_kes,description,source_treasurer_record_id,actor_user_id,approved_by) values(ledger_type,amount,old.title,_id,old.created_by,auth.uid());
  end if;
 end if;
 insert into private.club_financial_audit(actor_user_id,treasurer_record_id,action_key,old_data,new_data,reason,is_admin_override)
 values(auth.uid(),_id,case when adm or chair then 'chairman_admin_override_'||_decision else 'treasurer_'||_decision end,
 jsonb_build_object('status',old.status,'title',old.title,'amount_kes',old.amount_kes::text),
 jsonb_build_object('status',_decision,'title',old.title,'amount_kes',old.amount_kes::text),btrim(_reason),adm or chair);
 return true;
end $$;
revoke all on function public.treasurer_review_record(uuid,text,text) from public,anon;
grant execute on function public.treasurer_review_record(uuid,text,text) to authenticated;

create or replace function public.treasurer_confirm_opening_balance(_amount_kes numeric,_note text,_confirm_as text,_reason text default null)
returns boolean language plpgsql security definer set search_path=''
as $$
declare r text[]; adm boolean; old private.treasurer_opening_balance%rowtype;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles();adm:=private.is_active_platform_admin(auth.uid());
 if _amount_kes is null or _amount_kes<0 or _amount_kes>100000000000 or length(btrim(coalesce(_note,'')))<3 then raise exception 'Valid opening balance and explanation required'; end if;
 select * into old from private.treasurer_opening_balance where id=true for update;
 if found and old.locked_at is not null and not adm then raise exception 'Opening balance is locked; Platform Admin override required'; end if;
 if found and old.locked_at is not null and adm and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Platform Admin override reason required'; end if;
 if _confirm_as='treasurer' and ('treasurer'=any(r) or adm) then
  insert into private.treasurer_opening_balance(id,amount_kes,note,treasurer_confirmed_by,treasurer_confirmed_at,updated_by)
  values(true,_amount_kes,btrim(_note),auth.uid(),now(),auth.uid())
  on conflict(id) do update set amount_kes=excluded.amount_kes,note=excluded.note,treasurer_confirmed_by=auth.uid(),treasurer_confirmed_at=now(),updated_by=auth.uid(),updated_at=now();
 elsif _confirm_as='chairman' and ('chairman'=any(r) or adm) then
  if not found then raise exception 'Treasurer must record and confirm the opening balance first'; end if;
  if old.amount_kes<>_amount_kes then raise exception 'Chairman confirmation amount must match the Treasurer-confirmed amount'; end if;
  update private.treasurer_opening_balance set chairman_confirmed_by=auth.uid(),chairman_confirmed_at=now(),updated_by=auth.uid(),updated_at=now() where id=true;
 else raise exception 'Matching Treasurer or Chairman role required'; end if;
 if found and old.locked_at is not null and adm and _amount_kes<>old.amount_kes then
  insert into private.club_financial_ledger(entry_type,amount_kes,description,actor_user_id,approved_by) values('adjustment',_amount_kes-old.amount_kes,'Platform Admin opening-balance override: '||btrim(_reason),auth.uid(),auth.uid());
 end if;
 update private.treasurer_opening_balance set locked_at=coalesce(locked_at,now()) where id=true and treasurer_confirmed_at is not null and chairman_confirmed_at is not null;
 insert into private.club_financial_audit(actor_user_id,action_key,old_data,new_data,reason,is_admin_override)
 values(auth.uid(),'opening_balance_'||_confirm_as||'_confirmation',case when found then jsonb_build_object('amount_kes',old.amount_kes::text,'locked_at',old.locked_at) else '{}'::jsonb end,
 jsonb_build_object('amount_kes',_amount_kes::text,'confirm_as',_confirm_as),nullif(btrim(_reason),''),adm and old.locked_at is not null);
 if exists(select 1 from private.treasurer_opening_balance where id=true and locked_at is not null) and not exists(select 1 from private.club_financial_ledger where entry_type='opening_balance') then
  insert into private.club_financial_ledger(entry_type,amount_kes,description,actor_user_id,approved_by) values('opening_balance',_amount_kes,'Jointly confirmed opening balance',auth.uid(),auth.uid());
 end if;
 return true;
end $$;
revoke all on function public.treasurer_confirm_opening_balance(numeric,text,text,text) from public,anon;
grant execute on function public.treasurer_confirm_opening_balance(numeric,text,text,text) to authenticated;

-- Receipts are private by default. Folder name is the authenticated submitter's UUID.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('club-financial-receipts','club-financial-receipts',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['image/jpeg','image/png','image/webp','application/pdf'];

create or replace function public.treasurer_receipt_access(_owner text,_upload boolean default false)
returns boolean language plpgsql stable security definer set search_path=''
as $receipt$
declare r text[]; uid uuid; adm boolean;
begin
 uid:=auth.uid(); if uid is null then return false; end if;
 r:=private.current_club_roles(); adm:=private.is_active_platform_admin(uid);
 if _upload then return _owner=uid::text and (adm or r && array['chairman','treasurer','team_manager','coach','secretary','vice_chairman','player_welfare','sponsor_lead']::text[]); end if;
 return _owner=uid::text or adm or r && array['chairman','treasurer','secretary']::text[];
end $receipt$;
revoke all on function public.treasurer_receipt_access(text,boolean) from public,anon;
grant execute on function public.treasurer_receipt_access(text,boolean) to authenticated;

drop policy if exists treasurer_receipts_read on storage.objects;
create policy treasurer_receipts_read on storage.objects for select to authenticated
using(bucket_id='club-financial-receipts' and public.treasurer_receipt_access((storage.foldername(name))[1],false));
drop policy if exists treasurer_receipts_upload on storage.objects;
create policy treasurer_receipts_upload on storage.objects for insert to authenticated
with check(bucket_id='club-financial-receipts' and public.treasurer_receipt_access((storage.foldername(name))[1],true));
drop policy if exists treasurer_receipts_update on storage.objects;
create policy treasurer_receipts_update on storage.objects for update to authenticated
using(bucket_id='club-financial-receipts' and public.treasurer_receipt_access((storage.foldername(name))[1],true))
with check(bucket_id='club-financial-receipts' and public.treasurer_receipt_access((storage.foldername(name))[1],true));
drop policy if exists treasurer_receipts_delete on storage.objects;
create policy treasurer_receipts_delete on storage.objects for delete to authenticated using(false);


-- Sponsor accounts are read-only and scoped to records assigned to their auth UUID.
do $role$
declare c record;
begin
 for c in select conname from pg_constraint where conrelid='private.role_assignments'::regclass and contype='c' and pg_get_constraintdef(oid) ilike '%role_key%'
 loop execute format('alter table private.role_assignments drop constraint %I',c.conname); end loop;
 alter table private.role_assignments add constraint role_assignments_role_key_check
 check(role_key=any(array['chairman','vice_chairman','secretary','team_manager','treasurer','coach','sponsor_lead','media_team','player_welfare','sponsor']::text[]));
end $role$;
create or replace function public.treasurer_public_published_reports()
returns jsonb language sql stable security definer set search_path=''
as $report$
 select coalesce(jsonb_agg(jsonb_build_object('title',f.title,'record_date',f.record_date,'category',f.category,'payload',f.payload,'published_at',f.published_at) order by f.record_date desc),'[]'::jsonb)
 from private.treasurer_records f where f.record_type='financial_report' and f.status='published' and f.published_at is not null
$report$;
revoke all on function public.treasurer_public_published_reports() from public;
grant execute on function public.treasurer_public_published_reports() to anon,authenticated;

create or replace function public.treasurer_review_tm_transport(_id uuid,_decision text,_reason text,_approved_amount_kes numeric default null)
returns uuid language plpgsql security definer set search_path=''
as $transport$
declare r text[]; adm boolean; treas boolean; chair boolean; old private.tm_records%rowtype; rid uuid; amt numeric; payload jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 r:=private.current_club_roles();adm:=private.is_active_platform_admin(auth.uid());treas:=coalesce('treasurer'=any(r),false);chair:=coalesce('chairman'=any(r),false);
 if not(adm or treas or chair) then raise exception 'Treasurer, Chairman or Platform Admin required'; end if;
 if _decision not in('approved','rejected','queried') or length(btrim(coalesce(_reason,'')))<3 then raise exception 'Decision and reason required'; end if;
 select * into old from private.tm_records where id=_id and section_key='transport_logistics' for update;
 if not found then raise exception 'Team Manager transport plan not found'; end if;
 if old.created_by=auth.uid() then raise exception 'Cannot approve your own transport plan'; end if;
 if old.publication_status='approved' then raise exception 'Transport plan is already approved; submit an adjustment instead'; end if;
 if _decision='approved' then
  if _approved_amount_kes is null or _approved_amount_kes<=0 or _approved_amount_kes>100000000000 then raise exception 'Enter the explicitly approved total fare in KES'; end if;
  amt:=_approved_amount_kes;
  payload:=jsonb_build_object('source_tm_record_id',old.id,'trip_plan',old.data,'approval_reason',btrim(_reason));
  insert into private.treasurer_records(record_type,title,amount_kes,record_date,category,source,receipt_reference,payload,status,created_by,updated_by,submitted_by,reviewed_by,reviewed_at,review_reason)
  values('expense','Approved TM transport: '||coalesce(old.data->>'fixture','trip'),amt,current_date,'transport','Team Manager transport plan',old.id::text,payload,'approved',old.created_by,auth.uid(),old.created_by,auth.uid(),now(),btrim(_reason)) returning id into rid;
  insert into private.club_financial_ledger(entry_type,amount_kes,description,source_treasurer_record_id,actor_user_id,approved_by)
  values('expense',-amt,'Approved Team Manager transport: '||coalesce(old.data->>'fixture','trip'),rid,old.created_by,auth.uid());
  update private.tm_records set publication_status='approved',approved_by=auth.uid(),approved_at=now(),updated_by=auth.uid(),updated_at=now() where id=old.id;
 else
  rid:=old.id;
  update private.tm_records set treasurer_status=_decision,treasurer_reviewed_by=auth.uid(),treasurer_reviewed_at=now(),treasurer_review_reason=btrim(_reason),updated_by=auth.uid(),updated_at=now() where id=old.id;
 end if;
 if _decision='approved' then update private.tm_records set treasurer_status='approved',treasurer_reviewed_by=auth.uid(),treasurer_reviewed_at=now(),treasurer_review_reason=btrim(_reason) where id=old.id; end if;
 insert into private.tm_record_audit(actor_user_id,record_id,section_key,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(auth.uid(),old.id,'transport_logistics','treasurer_transport_'||_decision,old.data,
 case when _decision='approved' then jsonb_build_object('approved_amount_kes',_approved_amount_kes::text,'expense_record_id',rid) else old.data end,
 old.publication_status,case when _decision='approved' then 'approved' else old.publication_status end,adm or chair,btrim(_reason));
 insert into private.club_financial_audit(actor_user_id,treasurer_record_id,action_key,old_data,new_data,reason,is_admin_override)
 values(auth.uid(),rid,'tm_transport_'||_decision,jsonb_build_object('tm_record_id',old.id,'trip_plan',old.data),jsonb_build_object('approved_amount_kes',_approved_amount_kes::text,'decision',_decision),btrim(_reason),adm or chair);
 return rid;
end $transport$;
revoke all on function public.treasurer_review_tm_transport(uuid,text,text,numeric) from public,anon;
grant execute on function public.treasurer_review_tm_transport(uuid,text,text,numeric) to authenticated;

commit;

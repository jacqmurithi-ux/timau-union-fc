-- Team Manager expense submission, Treasurer approval, and canonical club ledger.
-- Apply to Union Test after the Team Manager workspace migration; validate before production.
begin;

create table if not exists private.club_financial_expenses(
 id uuid primary key default gen_random_uuid(),
 category text not null check(category in('transport','refreshments','kit_equipment','medical_first_aid','venue_pitch','other')),
 description text not null check(length(btrim(description)) between 3 and 3000),
 amount_kes numeric(12,2) not null check(amount_kes>0 and amount_kes<=100000000),
 expense_date date not null,
 status text not null default 'pending' check(status in('pending','approved','rejected')),
 created_by uuid not null references auth.users(id),
 updated_by uuid not null references auth.users(id),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 review_reason text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 approved_ledger_entry_id uuid,
 check((status='pending' and reviewed_by is null and reviewed_at is null) or status<>'pending'),
 check((status='approved' and approved_ledger_entry_id is not null) or status<>'approved')
);
create index if not exists club_financial_expenses_status_date_idx on private.club_financial_expenses(status,expense_date desc);
create index if not exists club_financial_expenses_creator_idx on private.club_financial_expenses(created_by,created_at desc);
alter table private.club_financial_expenses enable row level security;
revoke all on private.club_financial_expenses from public,anon,authenticated;
drop policy if exists club_financial_expenses_no_direct_access on private.club_financial_expenses;
create policy club_financial_expenses_no_direct_access on private.club_financial_expenses for all to anon,authenticated using(false) with check(false);

create table if not exists private.club_financial_ledger(
 id uuid primary key default gen_random_uuid(),
 entry_type text not null check(entry_type in('income','expense','expense_reversal','adjustment')),
 amount_kes numeric(12,2) not null check(amount_kes<>0),
 description text not null check(length(btrim(description)) between 3 and 3000),
 source_expense_id uuid references private.club_financial_expenses(id),
 actor_user_id uuid references auth.users(id),
 approved_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create index if not exists club_financial_ledger_created_idx on private.club_financial_ledger(created_at desc);
alter table private.club_financial_ledger enable row level security;
revoke all on private.club_financial_ledger from public,anon,authenticated;
drop policy if exists club_financial_ledger_no_direct_access on private.club_financial_ledger;
create policy club_financial_ledger_no_direct_access on private.club_financial_ledger for all to anon,authenticated using(false) with check(false);

create table if not exists private.club_financial_audit(
 id bigint generated always as identity primary key,
 actor_user_id uuid references auth.users(id) on delete set null,
 expense_id uuid references private.club_financial_expenses(id) on delete set null,
 action_key text not null,
 old_data jsonb not null default '{}'::jsonb check(jsonb_typeof(old_data)='object'),
 new_data jsonb not null default '{}'::jsonb check(jsonb_typeof(new_data)='object'),
 old_status text,
 new_status text,
 is_admin_override boolean not null default false,
 reason text,
 created_at timestamptz not null default now()
);
alter table private.club_financial_audit enable row level security;
revoke all on private.club_financial_audit from public,anon,authenticated;
drop policy if exists club_financial_audit_no_direct_access on private.club_financial_audit;
create policy club_financial_audit_no_direct_access on private.club_financial_audit for all to anon,authenticated using(false) with check(false);

create or replace function public.tm_get_expenses()
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid()); r:=private.current_club_roles();
 if not(adm or 'chairman'=any(r) or 'team_manager'=any(r) or 'treasurer'=any(r)) then raise exception 'Team Manager or Treasurer access required'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'id',e.id,'record_type','tm_expenses','data',jsonb_build_object('category',e.category,'description',e.description,'amount_kes',e.amount_kes::text,'expense_date',e.expense_date::text),
  'status',e.status,'publication_status',e.status,'created_by',e.created_by,'updated_by',e.updated_by,'reviewed_by',e.reviewed_by,'reviewed_at',e.reviewed_at,'review_reason',e.review_reason,'created_at',e.created_at,'updated_at',e.updated_at,
  'can_review',adm or 'chairman'=any(r) or 'treasurer'=any(r))
  order by case e.status when 'pending' then 0 when 'rejected' then 1 else 2 end,e.expense_date desc,e.created_at desc)
  from private.club_financial_expenses e),'[]'::jsonb);
end $f$;
revoke all on function public.tm_get_expenses() from public,anon;
grant execute on function public.tm_get_expenses() to authenticated;

create or replace function public.tm_submit_expense(_expense_id uuid,_data jsonb,_reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; tm boolean; oldrow private.club_financial_expenses%rowtype; id2 uuid; cat text; descr text; amt numeric; d date; oldj jsonb; newj jsonb;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();tm:='team_manager'=any(r);
 if not(adm or 'chairman'=any(r) or tm) then raise exception 'Only Team Manager or administrator can submit expenses'; end if;
 if _data is null or jsonb_typeof(_data)<>'object' or exists(select 1 from jsonb_object_keys(_data) k where k not in('category','description','amount_kes','expense_date')) then raise exception 'Invalid expense fields'; end if;
 cat:=_data->>'category'; descr:=btrim(coalesce(_data->>'description',''));
 begin amt:=(_data->>'amount_kes')::numeric; d:=(_data->>'expense_date')::date; exception when others then raise exception 'Enter a valid amount and expense date'; end;
 if cat is null or cat not in('transport','refreshments','kit_equipment','medical_first_aid','venue_pitch','other') or length(descr)<3 or length(descr)>3000 or amt is null or amt<=0 or amt>100000000 or d is null then raise exception 'Expense category, description, positive KES amount and date are required'; end if;
 newj:=jsonb_build_object('category',cat,'description',descr,'amount_kes',amt::text,'expense_date',d::text);
 if _expense_id is null then
  insert into private.club_financial_expenses(category,description,amount_kes,expense_date,created_by,updated_by)
  values(cat,descr,amt,d,auth.uid(),auth.uid()) returning id into id2;
  insert into private.club_financial_audit(actor_user_id,expense_id,action_key,new_data,new_status)
  values(auth.uid(),id2,'expense_submitted',newj,'pending');
 else
  select * into oldrow from private.club_financial_expenses where id=_expense_id for update;
  if not found then raise exception 'Expense not found'; end if;
  if not adm and not 'chairman'=any(r) and (not tm or oldrow.created_by<>auth.uid()) then raise exception 'Only the submitting Team Manager or administrator can edit this expense'; end if;
  if oldrow.status='approved' and not(adm or 'chairman'=any(r)) then raise exception 'Approved expenses are locked for financial integrity'; end if;
  if oldrow.status='approved' then
   insert into private.club_financial_ledger(entry_type,amount_kes,description,source_expense_id,actor_user_id,approved_by)
   values('expense_reversal',abs(oldrow.amount_kes),'Admin correction reversal: '||oldrow.description,oldrow.id,auth.uid(),auth.uid());
  end if;
  oldj:=jsonb_build_object('category',oldrow.category,'description',oldrow.description,'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text);
  update private.club_financial_expenses set category=cat,description=descr,amount_kes=amt,expense_date=d,status='pending',reviewed_by=null,reviewed_at=null,review_reason=null,approved_ledger_entry_id=null,updated_by=auth.uid(),updated_at=now() where id=_expense_id;
  id2:=_expense_id;
  insert into private.club_financial_audit(actor_user_id,expense_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
  values(auth.uid(),id2,case when adm or 'chairman'=any(r) and not tm then 'admin_override_expense_updated' else 'expense_updated' end,oldj,newj,oldrow.status,'pending',adm or ('chairman'=any(r) and not tm),case when adm or 'chairman'=any(r) and not tm then coalesce(nullif(btrim(_reason),''),'Administrator correction') else 'Updated; Treasurer approval required again' end);
 end if;
 return id2;
end $f$;
revoke all on function public.tm_submit_expense(uuid,jsonb,text) from public,anon;
grant execute on function public.tm_submit_expense(uuid,jsonb,text) to authenticated;

create or replace function public.tm_review_expense(_expense_id uuid,_decision text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $f$
declare r text[]; adm boolean; oldrow private.club_financial_expenses%rowtype; led uuid; over boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();over:=adm or 'chairman'=any(r);
 if not(over or 'treasurer'=any(r)) then raise exception 'Treasurer or administrator approval required'; end if;
 if _decision not in('approved','rejected') or _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then raise exception 'Valid decision and review reason required'; end if;
 select * into oldrow from private.club_financial_expenses where id=_expense_id for update;
 if not found then raise exception 'Expense not found'; end if;
 if oldrow.status<>'pending' then raise exception 'Only pending expenses can be reviewed'; end if;
 if _decision='approved' then
  insert into private.club_financial_ledger(entry_type,amount_kes,description,source_expense_id,actor_user_id,approved_by)
  values('expense',-oldrow.amount_kes,oldrow.category||': '||oldrow.description,oldrow.id,auth.uid(),auth.uid())
  returning id into led;
  update private.club_financial_expenses set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),review_reason=btrim(_reason),approved_ledger_entry_id=led,updated_by=auth.uid(),updated_at=now() where id=_expense_id;
 else
  update private.club_financial_expenses set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),review_reason=btrim(_reason),updated_by=auth.uid(),updated_at=now() where id=_expense_id;
 end if;
 insert into private.club_financial_audit(actor_user_id,expense_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
 values(auth.uid(),_expense_id,case when over then 'admin_override_'||_decision else 'treasurer_'||_decision end,
 jsonb_build_object('category',oldrow.category,'description',oldrow.description,'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text),
 jsonb_build_object('category',oldrow.category,'description',oldrow.description,'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text),
 'pending',_decision,over,btrim(_reason));
 return true;
end $f$;
revoke all on function public.tm_review_expense(uuid,text,text) from public,anon;
grant execute on function public.tm_review_expense(uuid,text,text) to authenticated;

create or replace function public.club_get_financial_summary()
returns jsonb language plpgsql stable security definer set search_path=''
as $f$
declare r text[]; adm boolean;
begin
 if auth.uid() is null then raise exception 'Sign-in required'; end if;
 adm:=private.is_active_platform_admin(auth.uid());r:=private.current_club_roles();
 if not(adm or coalesce(array_length(r,1),0)>0) then raise exception 'Approved club role required'; end if;
 return jsonb_build_object(
  'currency','KES',
  'approved_income_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger where entry_type='income'),0),
  'approved_expenses_kes',coalesce(-(select sum(amount_kes) from private.club_financial_ledger where entry_type in('expense','expense_reversal','adjustment')),0),
  'balance_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger),0),
  'pending_expenses_count',(select count(*) from private.club_financial_expenses where status='pending'),
  'pending_expenses_kes',coalesce((select sum(amount_kes) from private.club_financial_expenses where status='pending'),0),
  'ledger',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'entry_type',l.entry_type,'amount_kes',l.amount_kes,'description',l.description,'created_at',l.created_at,'approved_by',l.approved_by) order by l.created_at desc) from (select * from private.club_financial_ledger order by created_at desc limit 25) l),'[]'::jsonb)
 );
end $f$;
revoke all on function public.club_get_financial_summary() from public,anon;
grant execute on function public.club_get_financial_summary() to authenticated;

commit;

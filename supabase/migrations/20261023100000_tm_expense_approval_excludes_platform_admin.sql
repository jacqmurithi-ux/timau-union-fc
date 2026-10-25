-- Restrict club expense decisions to club officials; platform admins are not approvers.
-- Review and validate this migration against the target database before applying.
begin;

create or replace function public.tm_review_expense(_expense_id uuid,_decision text,_reason text)
returns boolean
language plpgsql
security definer
set search_path=''
as $f$
declare
 r text[];
 oldrow private.club_financial_expenses%rowtype;
 led uuid;
 action_name text;
begin
 if auth.uid() is null then
  raise exception 'Sign-in required';
 end if;

 -- Platform administration must not grant club expense approval authority,
 -- even if the same account also has a club role.
 if private.is_active_platform_admin(auth.uid()) then
  raise exception 'Platform Admin cannot approve or reject club expenses';
 end if;

 r:=private.current_club_roles();
 if not (r && array['chairman','secretary','treasurer']::text[]) then
  raise exception 'Chairperson, Secretary, or Treasurer approval required';
 end if;

 if _decision is null or _decision not in ('approved','rejected')
    or _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then
  raise exception 'Valid decision and review reason required';
 end if;

 select * into oldrow
 from private.club_financial_expenses
 where id=_expense_id
 for update;

 if not found then
  raise exception 'Expense not found';
 end if;
 if oldrow.created_by=auth.uid() then
  raise exception 'You cannot approve or reject your own expense';
 end if;
 if oldrow.status<>'pending' then
  raise exception 'Only pending expenses can be reviewed';
 end if;

 if _decision='approved' then
  insert into private.club_financial_ledger(entry_type,amount_kes,description,source_expense_id,actor_user_id,approved_by)
  values('expense',-oldrow.amount_kes,oldrow.category||': '||oldrow.description,oldrow.id,auth.uid(),auth.uid())
  returning id into led;

  update private.club_financial_expenses
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),
      review_reason=btrim(_reason),approved_ledger_entry_id=led,
      updated_by=auth.uid(),updated_at=now()
  where id=_expense_id;
 else
  update private.club_financial_expenses
  set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),
      review_reason=btrim(_reason),updated_by=auth.uid(),updated_at=now()
  where id=_expense_id;
 end if;

 action_name:=case
  when 'chairman'=any(r) then 'chairperson_'||_decision
  when 'secretary'=any(r) then 'secretary_'||_decision
  else 'treasurer_'||_decision
 end;

 insert into private.club_financial_audit(
  actor_user_id,expense_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason
 )
 values(
  auth.uid(),_expense_id,action_name,
  jsonb_build_object('category',oldrow.category,'description',oldrow.description,'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text),
  jsonb_build_object('category',oldrow.category,'description',oldrow.description,'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text),
  'pending',_decision,false,btrim(_reason)
 );

 return true;
end
$f$;

revoke all on function public.tm_review_expense(uuid,text,text) from public,anon;
grant execute on function public.tm_review_expense(uuid,text,text) to authenticated;

commit;

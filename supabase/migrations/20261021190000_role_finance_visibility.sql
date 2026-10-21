-- Restrict player editing for coaches and limit club financial records to finance officials.
begin;

create or replace function public.club_save_record(_record_id uuid, _record_type text, _data jsonb)
returns uuid
language plpgsql
security definer
set search_path=''
as $f$
declare
  r text[];
  adm boolean;
  id2 uuid;
  typ text;
  creator uuid;
  oldj jsonb;
  oldst text;
  override boolean;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  if not private.valid_club_record_data(_record_type,_data) then raise exception 'Invalid record type or field values'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  if not adm and coalesce(array_length(r,1),0)=0 then raise exception 'Approved active club role required'; end if;
  if not adm and not private.role_can_manage_record(r,_record_type) then raise exception 'Your role cannot edit this record type'; end if;
  if not adm and _record_type='player' and 'coach'=any(r)
     and not ('team_manager'=any(r) or 'chairman'=any(r)) then
    raise exception 'Coach role is read-only for player records';
  end if;
  if _record_id is not null then
    select record_type,created_by,data,publication_status into typ,creator,oldj,oldst
    from private.club_records where id=_record_id for update;
    if not found then raise exception 'Record not found'; end if;
    if not adm and (not private.role_can_manage_record(r,typ) or not private.can_manage_club_record(r,false,creator)) then
      raise exception 'Your role cannot edit this record';
    end if;
    if not adm and typ='player' and 'coach'=any(r)
       and not ('team_manager'=any(r) or 'chairman'=any(r)) then
      raise exception 'Coach role is read-only for player records';
    end if;
    override:=adm or 'chairman'=any(r);
    update private.club_records set record_type=_record_type,data=_data,publication_status='draft',
      approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now()
    where id=_record_id returning id into id2;
    insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason,old_data,new_data,is_admin_override,old_status,new_status)
    values(auth.uid(),id2,_record_type,case when override then 'admin_override_updated' else 'record_updated' end,
      case when override then 'Administrator override; saved as draft' else 'Saved as draft; approval reset' end,
      oldj,_data,override,oldst,'draft');
  else
    insert into private.club_records(record_type,data,created_by,updated_by)
    values(_record_type,_data,auth.uid(),auth.uid()) returning id into id2;
    insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,new_data)
    values(auth.uid(),id2,_record_type,'record_created',_data);
  end if;
  return id2;
end
$f$;

create or replace function public.tm_get_expenses()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $f$
declare
  r text[];
  adm boolean;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  if not (adm or r && array['chairman','secretary','treasurer']::text[]) then
    raise exception 'Chairman, Secretary, Treasurer, or Platform Admin access required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',e.id,'record_type','tm_expenses',
      'data',jsonb_build_object('category',e.category,'description',e.description,
        'amount_kes',e.amount_kes::text,'expense_date',e.expense_date::text,'squad_number',e.squad_number),
      'status',e.status,'publication_status',e.status,'created_by',e.created_by,
      'updated_by',e.updated_by,'reviewed_by',e.reviewed_by,'reviewed_at',e.reviewed_at,
      'review_reason',e.review_reason,'created_at',e.created_at,'updated_at',e.updated_at,
      'can_review',adm or r && array['chairman','secretary','treasurer']::text[]
    )
    order by case e.status when 'pending' then 0 when 'rejected' then 1 else 2 end,
      e.expense_date desc,e.created_at desc)
    from private.club_financial_expenses e
  ),'[]'::jsonb);
end
$f$;
revoke all on function public.tm_get_expenses() from public,anon;
grant execute on function public.tm_get_expenses() to authenticated;

create or replace function public.club_get_financial_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $f$
declare r text[]; adm boolean;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  if not (adm or r && array['chairman','secretary','treasurer']::text[]) then
    raise exception 'Chairman, Secretary, Treasurer, or Platform Admin access required';
  end if;
  return jsonb_build_object(
    'currency','KES',
    'approved_income_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger where entry_type='income'),0),
    'approved_expenses_kes',coalesce(-(select sum(amount_kes) from private.club_financial_ledger where entry_type in('expense','expense_reversal','adjustment')),0),
    'balance_kes',coalesce((select sum(amount_kes) from private.club_financial_ledger),0),
    'pending_expenses_count',(select count(*) from private.club_financial_expenses where status='pending'),
    'pending_expenses_kes',coalesce((select sum(amount_kes) from private.club_financial_expenses where status='pending'),0),
    'ledger',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'entry_type',l.entry_type,'amount_kes',l.amount_kes,'description',l.description,'created_at',l.created_at,'approved_by',l.approved_by) order by l.created_at desc)
      from (select * from private.club_financial_ledger order by created_at desc limit 25) l),'[]'::jsonb)
  );
end
$f$;
revoke all on function public.club_get_financial_summary() from public,anon;
grant execute on function public.club_get_financial_summary() to authenticated;

create or replace function public.tm_submit_expense(_expense_id uuid,_data jsonb,_reason text default null)
returns uuid
language plpgsql
security definer
set search_path=''
as $f$
declare
  r text[];
  adm boolean;
  tm boolean;
  oldrow private.club_financial_expenses%rowtype;
  id2 uuid;
  cat text;
  descr text;
  amt numeric;
  d date;
  squad text;
  oldj jsonb;
  newj jsonb;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  tm:='team_manager'=any(r);
  if not (adm or r && array['chairman','secretary','treasurer']::text[]) then
    raise exception 'Only Chairman, Secretary, Treasurer, or Platform Admin may access club expenses';
  end if;
  if _data is null or jsonb_typeof(_data)<>'object'
     or exists(select 1 from jsonb_object_keys(_data) k
               where k not in('category','description','amount_kes','expense_date','squad_number')) then
    raise exception 'Invalid expense fields';
  end if;
  cat:=_data->>'category';
  descr:=btrim(coalesce(_data->>'description',''));
  squad:=btrim(coalesce(_data->>'squad_number',''));
  begin
    amt:=(_data->>'amount_kes')::numeric;
    d:=(_data->>'expense_date')::date;
  exception when others then
    raise exception 'Enter a valid amount and expense date';
  end;
  if cat is null or cat not in('transport','refreshments','kit_equipment','medical_first_aid','venue_pitch','other')
     or length(descr)<3 or length(descr)>3000 or amt is null or amt<=0 or amt>100000000
     or d is null or length(squad)>80 then
    raise exception 'Expense category, purpose, positive KES amount and date are required; squad number must be 80 characters or fewer';
  end if;
  newj:=jsonb_build_object('category',cat,'description',descr,'amount_kes',amt::text,'expense_date',d::text,'squad_number',squad);
  if _expense_id is null then
    insert into private.club_financial_expenses(category,description,amount_kes,expense_date,squad_number,created_by,updated_by)
    values(cat,descr,amt,d,squad,auth.uid(),auth.uid()) returning id into id2;
    insert into private.club_financial_audit(actor_user_id,expense_id,action_key,new_data,new_status)
    values(auth.uid(),id2,'expense_submitted',newj,'pending');
  else
    select * into oldrow from private.club_financial_expenses where id=_expense_id for update;
    if not found then raise exception 'Expense not found'; end if;
    if not adm and not 'chairman'=any(r) and oldrow.created_by<>auth.uid() then
      raise exception 'You can edit only expenses you submitted';
    end if;
    if oldrow.status='approved' and not(adm or 'chairman'=any(r)) then
      raise exception 'Approved expenses are locked for financial integrity';
    end if;
    if oldrow.status='approved' then
      insert into private.club_financial_ledger(entry_type,amount_kes,description,source_expense_id,actor_user_id,approved_by)
      values('expense_reversal',abs(oldrow.amount_kes),'Admin correction reversal: '||oldrow.description,oldrow.id,auth.uid(),auth.uid());
    end if;
    oldj:=jsonb_build_object('category',oldrow.category,'description',oldrow.description,
      'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text,'squad_number',oldrow.squad_number);
    update private.club_financial_expenses set category=cat,description=descr,amount_kes=amt,expense_date=d,squad_number=squad,
      status='pending',reviewed_by=null,reviewed_at=null,review_reason=null,approved_ledger_entry_id=null,
      updated_by=auth.uid(),updated_at=now() where id=_expense_id;
    id2:=_expense_id;
    insert into private.club_financial_audit(actor_user_id,expense_id,action_key,old_data,new_data,old_status,new_status,is_admin_override,reason)
    values(auth.uid(),id2,
      case when adm or 'chairman'=any(r) and not tm then 'admin_override_expense_updated' else 'expense_updated' end,
      oldj,newj,oldrow.status,'pending',adm or ('chairman'=any(r) and not tm),
      case when adm or 'chairman'=any(r) and not tm then coalesce(nullif(btrim(_reason),''),'Administrator correction')
           else 'Updated; Treasurer approval required again' end);
  end if;
  return id2;
end
$f$;
revoke all on function public.tm_submit_expense(uuid,jsonb,text) from public,anon;
grant execute on function public.tm_submit_expense(uuid,jsonb,text) to authenticated;

commit;

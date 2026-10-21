-- Persist the optional squad number on expense drafts without changing approval or ledger rules.
begin;

alter table private.club_financial_expenses
  add column if not exists squad_number text not null default ''
  check (length(btrim(squad_number)) <= 80);

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
  adm := private.is_active_platform_admin(auth.uid());
  r := private.current_club_roles();
  if not (adm or coalesce(array_length(r,1),0)>0) then
    raise exception 'Active club role required';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',e.id,
      'record_type','tm_expenses',
      'data',jsonb_build_object(
        'category',e.category,
        'description',e.description,
        'amount_kes',e.amount_kes::text,
        'expense_date',e.expense_date::text,
        'squad_number',e.squad_number
      ),
      'status',e.status,
      'publication_status',e.status,
      'created_by',e.created_by,
      'updated_by',e.updated_by,
      'reviewed_by',e.reviewed_by,
      'reviewed_at',e.reviewed_at,
      'review_reason',e.review_reason,
      'created_at',e.created_at,
      'updated_at',e.updated_at,
      'can_review',adm or r && array['chairman','secretary','treasurer']::text[]
    )
    order by case e.status when 'pending' then 0 when 'rejected' then 1 else 2 end,
             e.expense_date desc,e.created_at desc)
    from private.club_financial_expenses e
    where adm or r && array['chairman','secretary','treasurer']::text[] or e.created_by=auth.uid()
  ),'[]'::jsonb);
end
$f$;

revoke all on function public.tm_get_expenses() from public,anon;
grant execute on function public.tm_get_expenses() to authenticated;

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
  if not (adm or coalesce(array_length(r,1),0)>0) then
    raise exception 'An active club role is required to submit an expense';
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
     or length(descr)<3 or length(descr)>3000
     or amt is null or amt<=0 or amt>100000000
     or d is null or length(squad)>80 then
    raise exception 'Expense category, purpose, positive KES amount and date are required; squad number must be 80 characters or fewer';
  end if;

  newj:=jsonb_build_object(
    'category',cat,'description',descr,'amount_kes',amt::text,
    'expense_date',d::text,'squad_number',squad
  );

  if _expense_id is null then
    insert into private.club_financial_expenses(
      category,description,amount_kes,expense_date,squad_number,created_by,updated_by
    ) values(cat,descr,amt,d,squad,auth.uid(),auth.uid())
    returning id into id2;

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

    oldj:=jsonb_build_object(
      'category',oldrow.category,'description',oldrow.description,
      'amount_kes',oldrow.amount_kes::text,'expense_date',oldrow.expense_date::text,
      'squad_number',oldrow.squad_number
    );

    update private.club_financial_expenses
    set category=cat,description=descr,amount_kes=amt,expense_date=d,squad_number=squad,
        status='pending',reviewed_by=null,reviewed_at=null,review_reason=null,
        approved_ledger_entry_id=null,updated_by=auth.uid(),updated_at=now()
    where id=_expense_id;
    id2:=_expense_id;

    insert into private.club_financial_audit(
      actor_user_id,expense_id,action_key,old_data,new_data,old_status,new_status,
      is_admin_override,reason
    ) values(
      auth.uid(),id2,
      case when adm or 'chairman'=any(r) and not tm then 'admin_override_expense_updated' else 'expense_updated' end,
      oldj,newj,oldrow.status,'pending',
      adm or ('chairman'=any(r) and not tm),
      case when adm or 'chairman'=any(r) and not tm then coalesce(nullif(btrim(_reason),''),'Administrator correction')
           else 'Updated; Treasurer approval required again' end
    );
  end if;
  return id2;
end
$f$;

revoke all on function public.tm_submit_expense(uuid,jsonb,text) from public,anon;
grant execute on function public.tm_submit_expense(uuid,jsonb,text) to authenticated;

commit;

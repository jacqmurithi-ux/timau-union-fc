-- Permit the intended approved -> published transition for financial reports.
-- Approved accounting entries remain immutable; publishing a report does not post a ledger entry.
create or replace function public.treasurer_review_record(_id uuid, _decision text, _reason text)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  r text[];
  adm boolean;
  treas boolean;
  chair boolean;
  old private.treasurer_records%rowtype;
  ledger_type text;
  amount numeric;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  r:=private.current_club_roles();
  adm:=private.is_active_platform_admin(auth.uid());
  treas:=coalesce('treasurer'=any(r),false);
  chair:=coalesce('chairman'=any(r),false);
  if not (adm or treas or chair) then
    raise exception 'Treasurer, Chairman or Platform Admin required' using errcode='42501';
  end if;
  if _decision not in ('approved','rejected','queried','published')
     or length(btrim(coalesce(_reason,'')))<3 then
    raise exception 'Decision and reason (minimum 3 characters) required' using errcode='22023';
  end if;

  select * into old from private.treasurer_records where id=_id for update;
  if not found then raise exception 'Record not found'; end if;

  if old.status='published' then
    raise exception 'Published records are immutable; create a new report version';
  end if;
  if old.status='approved'
     and not (old.record_type='financial_report' and _decision='published') then
    raise exception 'Approved finance records are immutable; create a separately reviewed adjustment or reversal';
  end if;
  if _decision='published' then
    if old.record_type<>'financial_report' then raise exception 'Only financial reports may be published'; end if;
    if old.status<>'approved' then raise exception 'A financial report must be approved before publication'; end if;
    if not (adm or chair) then raise exception 'Chairman or Platform Admin must explicitly publish approved reports' using errcode='42501'; end if;
  end if;
  if old.record_type='requisition' and not (adm or treas or chair) then
    raise exception 'Cannot review requisition' using errcode='42501';
  end if;
  if old.status='pending' and old.submitted_by=auth.uid() then
    raise exception 'Cannot approve your own requisition' using errcode='42501';
  end if;

  update private.treasurer_records
    set status=_decision,
        reviewed_by=auth.uid(),
        reviewed_at=now(),
        review_reason=btrim(_reason),
        published_at=case when _decision='published' then now() else null end,
        updated_by=auth.uid(),
        updated_at=now()
    where id=_id;

  if _decision='approved' and old.status<>'approved' then
    if old.record_type='income' then ledger_type:='income'; amount:=old.amount_kes;
    elsif old.record_type='sponsor_fund' and lower(coalesce(old.category,''))='received' then ledger_type:='income'; amount:=old.amount_kes;
    elsif old.record_type='member_contribution' and lower(coalesce(old.category,'')) in ('paid','received') then ledger_type:='income'; amount:=old.amount_kes;
    elsif old.record_type='expense' or old.record_type='transport_approval' then ledger_type:='expense'; amount:=-old.amount_kes;
    end if;
    if ledger_type is not null and amount<>0 then
      insert into private.club_financial_ledger(
        entry_type,amount_kes,description,source_treasurer_record_id,actor_user_id,approved_by,transaction_date
      ) values (
        ledger_type,amount,old.title,_id,old.created_by,auth.uid(),coalesce(old.record_date,current_date)
      );
    end if;
  end if;

  insert into private.club_financial_audit(
    actor_user_id,treasurer_record_id,action_key,old_data,new_data,reason,is_admin_override
  ) values (
    auth.uid(),_id,
    case when adm or chair then 'chairman_admin_override_'||_decision else 'treasurer_'||_decision end,
    jsonb_build_object('status',old.status,'title',old.title,'amount_kes',old.amount_kes::text),
    jsonb_build_object('status',_decision,'title',old.title,'amount_kes',old.amount_kes::text),
    btrim(_reason),adm or chair
  );
  return true;
end
$function$;

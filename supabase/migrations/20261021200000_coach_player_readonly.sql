-- Coaches may view player records but cannot publish, archive, or return them to draft.
begin;

create or replace function public.club_set_publication_status(_record_id uuid, _new_status text, _reason text)
returns boolean
language plpgsql
security definer
set search_path=''
as $f$
declare
  r text[];
  adm boolean;
  typ text;
  creator uuid;
  d jsonb;
  oldst text;
  over boolean;
begin
  if auth.uid() is null then raise exception 'Sign-in required'; end if;
  adm:=private.is_active_platform_admin(auth.uid());
  r:=private.current_club_roles();
  if _new_status not in('approved','archived','draft') then raise exception 'Invalid publication status'; end if;
  if _reason is null or length(btrim(_reason))<3 or length(_reason)>1000 then
    raise exception 'Reason of 3 to 1000 characters required';
  end if;
  select record_type,created_by,data,publication_status into typ,creator,d,oldst
  from private.club_records where id=_record_id for update;
  if not found then raise exception 'Record not found'; end if;
  if not adm and typ='player' and 'coach'=any(r)
     and not ('team_manager'=any(r) or 'chairman'=any(r)) then
    raise exception 'Coach role cannot approve, archive, or return player records to draft';
  end if;
  if not adm and (not private.role_can_manage_record(r,typ) or not private.can_manage_club_record(r,false,creator)) then
    raise exception 'Your role cannot change publication status';
  end if;
  over:=adm or 'chairman'=any(r);
  update private.club_records set publication_status=_new_status,
    approved_by=case when _new_status='approved' then auth.uid() else null end,
    approved_at=case when _new_status='approved' then now() else null end,
    updated_by=auth.uid(),updated_at=now()
  where id=_record_id;
  insert into private.club_record_audit(actor_user_id,record_id,record_type,action_key,reason,old_data,new_data,is_admin_override,old_status,new_status)
  values(auth.uid(),_record_id,typ,
    case when over then 'admin_override_publication_'||_new_status else 'publication_'||_new_status end,
    btrim(_reason),d,d,over,oldst,_new_status);
  return true;
end
$f$;

revoke all on function public.club_set_publication_status(uuid,text,text) from public,anon;
grant execute on function public.club_set_publication_status(uuid,text,text) to authenticated;

commit;

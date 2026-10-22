-- Avoid linking an accepted proposal to an unrelated agreement by sponsor name/package.
-- Create and link the draft agreement while the proposal is still sent, then transition it to accepted.
-- This ordering is required by the database trigger that makes accepted proposals immutable.
begin;

create or replace function public.sponsor_proposal_set_status(_id uuid,_status text,_reason text default null)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare
 r text[];
 admin boolean;
 chairman boolean;
 old_j jsonb;
 new_j jsonb;
 rid uuid;
 current_status text;
begin
 if auth.uid() is null then
  raise exception 'Authentication required';
 end if;

 r:=private.current_club_roles();
 admin:=private.is_active_platform_admin(auth.uid());
 chairman:=admin or 'chairman'=any(r);

 if not private.sponsor_eval_can_manage() then
  raise exception 'Sponsor Lead, Chairman or admin required';
 end if;
 if _status not in ('approved','sent','accepted','declined') then
  raise exception 'Invalid proposal status';
 end if;
 if not chairman then
  raise exception 'Chairman or admin approval required';
 end if;
 if admin and length(btrim(coalesce(_reason,'')))<3 then
  raise exception 'Admin override reason required';
 end if;

 select to_jsonb(p),p.status
 into old_j,current_status
 from private.sponsor_proposals p
 where p.id=_id
 for update;

 if old_j is null then
  raise exception 'Proposal not found';
 end if;

 -- State machine: draft -> approved -> sent -> accepted|declined.
 -- No privileged role can skip a state. Admin actions require and retain an audit reason.
 if _status='approved' and current_status not in ('draft','approved') then
  raise exception 'Only a draft proposal can be approved';
 end if;
 if _status='sent' and current_status<>'approved' then
  raise exception 'Proposal must be approved before it can be marked sent';
 end if;
 if _status in ('accepted','declined') and current_status<>'sent' then
  raise exception 'Proposal must be marked sent before recording sponsor response';
 end if;

 if _status='accepted' then
  -- Never infer agreement identity from sponsor name/package: duplicates and
  -- closed/expired agreements can share those values. Always create a new
  -- draft agreement for explicit Chairman review and linking.
  insert into private.sponsor_agreements
   (sponsor_name,package_id,amount_kes,obligations,payment_schedule,status,created_by,updated_by)
  select sp.sponsor_name,p.package_id,p.amount_kes,'','',
         'draft',auth.uid(),auth.uid()
  from private.sponsor_proposals p
  join private.sponsor_prospects sp on sp.id=p.prospect_id
  where p.id=_id
  returning id into rid;

  if rid is null then
   raise exception 'Could not create draft agreement for accepted proposal';
  end if;

  update private.sponsor_proposals
  set agreement_id=rid
  where id=_id;

 end if;

 update private.sponsor_proposals
 set status=_status,
     approved_by=case when _status='approved' then auth.uid() else approved_by end,
     approved_at=case when _status='approved' then now() else approved_at end,
     sent_at=case when _status='sent' then now() else sent_at end,
     sent_by=case when _status='sent' then auth.uid() else sent_by end,
     updated_by=auth.uid(),
     updated_at=now()
 where id=_id;


 select to_jsonb(p) into new_j
 from private.sponsor_proposals p
 where p.id=_id;

 insert into private.sponsor_workspace_audit
  (actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values
  (auth.uid(),'sponsor_proposals',_id,
   case when admin then 'admin_override' else 'proposal_status_changed' end,
   old_j,new_j,
   case when admin then btrim(_reason) else nullif(btrim(_reason),'') end);
end
$$;

revoke all on function public.sponsor_proposal_set_status(uuid,text,text) from public,anon;
grant execute on function public.sponsor_proposal_set_status(uuid,text,text) to authenticated;


commit;

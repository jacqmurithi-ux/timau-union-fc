-- Prevent editing an accepted sponsor proposal in place.
-- Accepted proposals are immutable: create a new proposal for any subsequent offer.
-- Candidate migration; do not apply to production until schema/dependency reconciliation is complete.
begin;

create or replace function public.sponsor_proposal_save(
 _id uuid,
 _prospect_id uuid,
 _package_id uuid,
 _template_id uuid,
 _title text,
 _content_html text,
 _amount_kes numeric,
 _duration text,
 _follow_up_date date,
 _reason text default null
)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
 r text[];
 admin boolean;
 rid uuid;
 old_j jsonb;
 old_status text;
 vno integer;
begin
 if auth.uid() is null then
  raise exception 'Authentication required';
 end if;

 r:=private.current_club_roles();
 admin:=private.is_active_platform_admin(auth.uid());

 if not private.sponsor_eval_can_manage() then
  raise exception 'Sponsor Lead, Chairman or admin required';
 end if;

 if admin and _id is not null and length(btrim(coalesce(_reason,'')))<3 then
  raise exception 'Admin override reason required';
 end if;

 if _id is null then
  insert into private.sponsor_proposals
   (prospect_id,package_id,template_id,title,content_html,amount_kes,duration,follow_up_date,created_by,updated_by)
  values
   (_prospect_id,_package_id,_template_id,_title,_content_html,_amount_kes,coalesce(_duration,''),_follow_up_date,auth.uid(),auth.uid())
  returning id into rid;
 else
  select to_jsonb(p),p.status
   into old_j,old_status
  from private.sponsor_proposals p
  where p.id=_id
  for update;

  if old_j is null then
   raise exception 'Proposal not found';
  end if;

  -- Once accepted, the submitted offer must remain a faithful record.
  -- Chairman/admin cannot edit it in place either; create a new proposal.
  if old_status='accepted' then
   raise exception 'Accepted proposals are immutable; create a new proposal for changes';
  end if;

  if old_status in ('sent','declined') and not (admin or 'chairman'=any(r)) then
   raise exception 'Only Chairman or admin can change a finalized proposal';
  end if;

  update private.sponsor_proposals
  set prospect_id=_prospect_id,
      package_id=_package_id,
      template_id=_template_id,
      title=_title,
      content_html=_content_html,
      amount_kes=_amount_kes,
      duration=coalesce(_duration,''),
      follow_up_date=_follow_up_date,
      updated_by=auth.uid(),
      updated_at=now(),
      status=case when status='approved' then 'draft' else status end
  where id=_id
  returning id into rid;
 end if;

 select coalesce(max(version_no),0)+1
 into vno
 from private.sponsor_proposal_versions
 where proposal_id=rid;

 insert into private.sponsor_proposal_versions
  (proposal_id,version_no,content_html,status,changed_by)
 values
  (rid,vno,_content_html,'draft',auth.uid());

 insert into private.sponsor_workspace_audit
  (actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values
  (auth.uid(),'sponsor_proposals',rid,
   case when admin and _id is not null then 'admin_override'
        when _id is null then 'proposal_created'
        else 'proposal_version_saved' end,
   old_j,
   jsonb_build_object('title',_title,'content_html',_content_html,'amount_kes',_amount_kes,'status','draft','version_no',vno),
   case when admin and _id is not null then btrim(_reason) else nullif(btrim(_reason),'') end);

 return rid;
end
$$;

revoke all on function public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date,text) from public,anon;
grant execute on function public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date,text) to authenticated;

commit;

-- Custom proposal naming, idempotent starter seed, duplicate-name enforcement and approval placeholder guard.
begin;
create unique index if not exists sponsor_proposal_templates_normalized_name_uidx on private.sponsor_proposal_templates(lower(btrim(name)));
create unique index if not exists sponsor_proposals_normalized_title_uidx on private.sponsor_proposals(lower(btrim(title)));
create or replace function public.sponsor_eval_get_workspace()
returns jsonb language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; lead boolean; chairman boolean; treasurer boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 chairman:=admin or 'chairman'=any(r); lead:=chairman or 'sponsor_lead'=any(r); treasurer:=chairman or 'treasurer'=any(r);
 if not (lead or treasurer) then raise exception 'Sponsor Lead, Chairman, Treasurer or admin required'; end if;
 return jsonb_build_object(
 'is_admin',admin,'is_chairman',chairman,
 'settings',case when chairman then (select to_jsonb(s) from private.sponsor_evaluation_settings s where id=true) else '{}'::jsonb end,
 'evaluations',case when lead then coalesce((select jsonb_agg(to_jsonb(e) order by e.evaluated_at desc) from private.sponsor_prospect_evaluations e),'[]'::jsonb) else '[]'::jsonb end,
 'templates',case when lead then coalesce((select jsonb_agg(to_jsonb(t) order by t.is_starter desc,t.name) from private.sponsor_proposal_templates t where (lower(btrim(t.name)) not in ('kit sponsor proposal','match day sponsor proposal','community partner proposal','custom sponsor proposal') and not (t.is_starter and t.template_kind='custom')) or admin or 'sponsor_lead'=any(r)),'[]'::jsonb) else '[]'::jsonb end,
 'proposals',case when lead then coalesce((select jsonb_agg(to_jsonb(p) order by p.updated_at desc) from private.sponsor_proposals p),'[]'::jsonb)
 when treasurer then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'prospect_id',p.prospect_id,'title',p.title,'amount_kes',p.amount_kes,'status',p.status,'duration',p.duration) order by p.updated_at desc) from private.sponsor_proposals p),'[]'::jsonb) else '[]'::jsonb end,
 'proposal_versions',case when lead then coalesce((select jsonb_agg(to_jsonb(v) order by v.changed_at desc) from private.sponsor_proposal_versions v),'[]'::jsonb) else '[]'::jsonb end
 );
end $$;
revoke all on function public.sponsor_eval_get_workspace() from public,anon;
grant execute on function public.sponsor_eval_get_workspace() to authenticated;

create or replace function public.sponsor_template_save(_name text,_kind text,_sections jsonb)
returns uuid language plpgsql security definer set search_path=''
as $sponsor_template$
declare r text[]; admin boolean; rid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if length(btrim(coalesce(_name,'')))<2 or _kind not in ('kit_sponsor','match_day_sponsor','community_partner','custom') or jsonb_typeof(_sections)<>'object' then raise exception 'Valid template name, kind and sections required'; end if;
 if lower(btrim(_name)) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal','custom sponsor proposal') and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can create these restricted starter templates';
 end if;
 if exists(select 1 from private.sponsor_proposal_templates t where lower(btrim(t.name))=lower(btrim(_name))) then raise exception 'A template with this name already exists. Choose a unique name.'; end if;
 insert into private.sponsor_proposal_templates(name,template_kind,sections,is_starter,status,created_by,updated_by)
 values(btrim(_name),_kind,_sections,false,'draft',auth.uid(),auth.uid()) returning id into rid;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data)
 values(auth.uid(),'sponsor_proposal_templates',rid,'template_created',jsonb_build_object('name',_name,'template_kind',_kind,'sections',_sections,'status','draft'));
 return rid;
end $sponsor_template$;
revoke all on function public.sponsor_template_save(text,text,jsonb) from public,anon;
grant execute on function public.sponsor_template_save(text,text,jsonb) to authenticated;

create or replace function public.sponsor_template_update(_id uuid,_name text,_kind text,_sections jsonb,_reason text default null)
returns void language plpgsql security definer set search_path=''
as $sponsor_template_update$
declare r text[]; admin boolean; old_j jsonb; new_j jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if admin and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Admin override reason required'; end if;
 select to_jsonb(t) into old_j from private.sponsor_proposal_templates t where id=_id for update;
 if old_j is null then raise exception 'Template not found'; end if;
 if (lower(btrim(coalesce(old_j->>'name',''))) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal','custom sponsor proposal') or lower(btrim(coalesce(_name,''))) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal'))
    and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can view or edit these restricted starter templates';
 end if;
 if exists(select 1 from private.sponsor_proposal_templates t where lower(btrim(t.name))=lower(btrim(_name)) and t.id<>_id) then raise exception 'A template with this name already exists. Choose a unique name.'; end if;
 update private.sponsor_proposal_templates set name=btrim(_name),template_kind=_kind,sections=_sections,updated_by=auth.uid(),updated_at=now() where id=_id;
 select to_jsonb(t) into new_j from private.sponsor_proposal_templates t where id=_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_proposal_templates',_id,case when admin then 'admin_override' else 'template_updated' end,old_j,new_j,_reason);
end $sponsor_template_update$;
revoke all on function public.sponsor_template_update(uuid,text,text,jsonb,text) from public,anon;
grant execute on function public.sponsor_template_update(uuid,text,text,jsonb,text) to authenticated;

create or replace function public.sponsor_proposal_save(_id uuid,_prospect_id uuid,_package_id uuid,_template_id uuid,_title text,_content_html text,_amount_kes numeric,_duration text,_follow_up_date date,_reason text default null)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; rid uuid; old_j jsonb; vno integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not private.sponsor_eval_can_manage() then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if admin and _id is not null and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Admin override reason required'; end if;
 if length(btrim(coalesce(_title,'')))=0 then raise exception 'Proposal name is required'; end if;
 if exists(select 1 from private.sponsor_proposals p where lower(btrim(p.title))=lower(btrim(_title)) and p.id is distinct from _id) then raise exception 'A proposal with this name already exists. Choose a unique name.'; end if;
 if _id is null then
  insert into private.sponsor_proposals(prospect_id,package_id,template_id,title,content_html,amount_kes,duration,follow_up_date,created_by,updated_by)
  values(_prospect_id,_package_id,_template_id,btrim(_title),_content_html,_amount_kes,coalesce(_duration,''),_follow_up_date,auth.uid(),auth.uid()) returning id into rid;
 else
  select to_jsonb(p) into old_j from private.sponsor_proposals p where id=_id for update;
  if old_j is null then raise exception 'Proposal not found'; end if;
  if old_j->>'status' in ('sent','accepted','declined') and not (admin or 'chairman'=any(r)) then raise exception 'Only Chairman or admin can change a finalized proposal'; end if;
  update private.sponsor_proposals set prospect_id=_prospect_id,package_id=_package_id,template_id=_template_id,title=btrim(_title),content_html=_content_html,amount_kes=_amount_kes,duration=coalesce(_duration,''),follow_up_date=_follow_up_date,updated_by=auth.uid(),updated_at=now(),status=case when status='approved' then 'draft' else status end where id=_id returning id into rid;
 end if;
 select coalesce(max(version_no),0)+1 into vno from private.sponsor_proposal_versions where proposal_id=rid;
 insert into private.sponsor_proposal_versions(proposal_id,version_no,content_html,status,changed_by) values(rid,vno,_content_html,'draft',auth.uid());
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason) values(auth.uid(),'sponsor_proposals',rid,case when admin and _id is not null then 'admin_override' when _id is null then 'proposal_created' else 'proposal_version_saved' end,old_j,jsonb_build_object('title',_title,'content_html',_content_html,'amount_kes',_amount_kes,'status','draft','version_no',vno),_reason);
 return rid;
end $$;
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
 if _status='approved' and coalesce(old_j->>'content_html','') ~ E'\\\\[[^][]+\\\\]' then
  raise exception 'Cannot approve or send this proposal while bracketed placeholders remain';
 end if;
 if _status='approved' and current_status not in ('draft','approved') then
  raise exception 'Only a draft proposal can be approved';
 end if;
 if _status='sent' and current_status<>'approved' then
  raise exception 'Proposal must be approved before it can be marked sent';
 end if;
 if _status in ('accepted','declined') and current_status<>'sent' then
  raise exception 'Proposal must be marked sent before recording sponsor response';
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

 if _status='accepted' then
  update private.sponsor_proposals p
  set agreement_id=coalesce(
   p.agreement_id,
   (select a.id
    from private.sponsor_agreements a
    where a.sponsor_name=(
      select sp.sponsor_name
      from private.sponsor_prospects sp
      where sp.id=p.prospect_id
    )
    and a.package_id is not distinct from p.package_id
    order by a.created_at desc
    limit 1)
  )
  where p.id=_id;

  if not exists(
   select 1 from private.sponsor_proposals p
   where p.id=_id and p.agreement_id is not null
  ) then
   insert into private.sponsor_agreements
    (sponsor_name,package_id,amount_kes,obligations,payment_schedule,status,created_by,updated_by)
   select sp.sponsor_name,p.package_id,p.amount_kes,'','',
          'draft',auth.uid(),auth.uid()
   from private.sponsor_proposals p
   join private.sponsor_prospects sp on sp.id=p.prospect_id
   where p.id=_id
   returning id into rid;

   update private.sponsor_proposals set agreement_id=rid where id=_id;
  end if;
 end if;

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

-- Safe idempotent starter seed. Never overwrite existing templates.
do $seed$
declare seed_user uuid; seed_id uuid; seed_sections jsonb;
begin
 select u.id into seed_user from auth.users u order by u.created_at,u.id limit 1;
 if seed_user is null then raise notice 'Custom Sponsor Proposal seed skipped: no auth user exists'; return; end if;
 if exists(select 1 from private.sponsor_proposal_templates t where (t.template_kind='custom' and t.is_starter=true) or lower(btrim(t.name))='custom sponsor proposal') then
   raise notice 'Custom starter already exists; seed skipped without changes'; return;
 end if;
 seed_sections:=jsonb_build_object(
 'cover', E'{proposal_name}\nPrepared for {sponsor_name}\nAttention: {contact_person}\nTimau Union FC, {date}',
 'about_club', E'Timau Union FC is a community football club based in Timau, Meru County, competing in the Meru County League. We bring together local players and supporters, and we create opportunities for young people through football.\n\n[Add year founded, number of players, and anything relevant to this sponsor.]',
 'achievements', E'- Second place in the zone and playoff qualification in the 2025 Meru County League.\n- Second place in the zone and playoff qualification in the 2026 Meru County League.\n- [Add other verified achievements.]',
 'audience_reach', E'The club is followed by players, families, supporters and local businesses across Timau and nearby communities.\n\nTypical match attendance: [verified figure].\nSocial media followers: [verified figure].\n[Add anything else that matters to this sponsor, such as the audience they want to reach.]',
 'packages', E'Package: {package_name}\nThis package makes {sponsor_name} a sponsor of Timau Union FC for {duration}.\n\n[Describe exactly what is being sponsored and what is covered.]',
 'benefits', E'{benefits}\n\n[List the benefits agreed or proposed for this sponsor, for example: logo placement, social media mentions, match announcements, website listing, event invitations, activations.]',
 'investment', E'The investment for {package_name} is {amount} for {duration}.\n\n[Add payment schedule and whether in-kind support is accepted, with an agreed value.]',
 'terms', E'- The sponsorship runs for {duration} from the signing date.\n- Payment is made as agreed, to the club''s official account.\n- The club will display the sponsor''s name and logo only after the sponsor approves the artwork.\n- The club will not share photos of players under 18 for promotional use without the consent of a parent or guardian.\n- [Add any terms specific to this sponsor: exclusivity, cancellation, renewal.]\n- Either party may end the agreement with [notice period] written notice.\n- A signed agreement will be completed before the sponsorship starts.',
 'next_steps', E'To go ahead, please contact {club_contact}. We will confirm the details of the package, agree the benefits, and prepare the agreement.\n\nThank you for considering a partnership with Timau Union FC.',
 '_verification',jsonb_build_object('achievements',false,'audience_reach',false)
 );
 insert into private.sponsor_proposal_templates(name,template_kind,sections,is_starter,status,created_by,updated_by)
 values('Custom Sponsor Proposal','custom',seed_sections,true,'draft',seed_user,seed_user) returning id into seed_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data,reason)
 values(null,'sponsor_proposal_templates',seed_id,'template_seeded',jsonb_build_object('name','Custom Sponsor Proposal','template_kind','custom','status','draft','is_starter',true,'sections',seed_sections),'One-time idempotent Custom starter seed; no unverified figures or facts added.');
end $seed$;

commit;

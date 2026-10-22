-- Seed a professional Kit Sponsor Proposal starter template as a private draft.
-- Idempotent: preserve any existing template with this name and do not overwrite user edits.
begin;

alter table private.sponsor_proposal_templates
  add column if not exists status text not null default 'draft';

do $constraint$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sponsor_proposal_templates_status_check'
      and conrelid = 'private.sponsor_proposal_templates'::regclass
  ) then
    alter table private.sponsor_proposal_templates
      add constraint sponsor_proposal_templates_status_check
      check (status in ('draft','approved'));
  end if;
end
$constraint$;

-- The Kit Sponsor Proposal is visible only to Sponsor Lead and platform admins.
-- Other templates retain the existing Sponsor Lead/Chairman/admin access model.
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
 'templates',case when lead then coalesce((select jsonb_agg(to_jsonb(t) order by t.is_starter desc,t.name) from private.sponsor_proposal_templates t where lower(btrim(t.name)) <> 'kit sponsor proposal' or admin or 'sponsor_lead'=any(r)),'[]'::jsonb) else '[]'::jsonb end,
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
 if lower(btrim(_name))='kit sponsor proposal' and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can create the Kit Sponsor Proposal template';
 end if;
 insert into private.sponsor_proposal_templates(name,template_kind,sections,is_starter,status,created_by,updated_by)
 values(_name,_kind,_sections,false,'draft',auth.uid(),auth.uid()) returning id into rid;
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
 if (lower(btrim(coalesce(old_j->>'name','')))='kit sponsor proposal' or lower(btrim(coalesce(_name,'')))='kit sponsor proposal')
    and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can view or edit the Kit Sponsor Proposal template';
 end if;
 update private.sponsor_proposal_templates set name=_name,template_kind=_kind,sections=_sections,updated_by=auth.uid(),updated_at=now() where id=_id;
 select to_jsonb(t) into new_j from private.sponsor_proposal_templates t where id=_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_proposal_templates',_id,case when admin then 'admin_override' else 'template_updated' end,old_j,new_j,_reason);
end $sponsor_template_update$;
revoke all on function public.sponsor_template_update(uuid,text,text,jsonb,text) from public,anon;
grant execute on function public.sponsor_template_update(uuid,text,text,jsonb,text) to authenticated;

-- Never overwrite an existing template with this name, including an edited or renamed draft.
do $seed$
declare
  seed_user uuid;
  seed_id uuid;
  seed_sections jsonb;
begin
  select u.id into seed_user from auth.users u order by u.created_at, u.id limit 1;
  if seed_user is null then
    raise notice 'Kit Sponsor Proposal seed skipped: no auth user exists to own the draft';
    return;
  end if;

  if exists (
    select 1 from private.sponsor_proposal_templates t
    where lower(btrim(t.name)) = 'kit sponsor proposal'
  ) then
    raise notice 'Kit Sponsor Proposal already exists; seed skipped without modifying it';
    return;
  end if;

  seed_sections := jsonb_build_object(
    'cover', E'KIT SPONSORSHIP PROPOSAL\nPrepared for {sponsor_name}\nAttention: {contact_person}\nTimau Union FC, {date}',
    'about_club', E'Timau Union FC is a community football club based in Timau, Meru County, competing in the Meru County League. We bring together local players and supporters, and we create opportunities for young people through football.\n\n[Add year founded and number of players.]',
    'achievements', E'- Second place in the zone and playoff qualification in the 2025 Meru County League.\n- Second place in the zone and playoff qualification in the 2026 Meru County League.\n- [Add other verified achievements.]',
    'audience_reach', E'Our matches bring together players, families and supporters from Timau and nearby communities.\n\nTypical match attendance: [verified figure].\nSocial media followers: [verified figure].\nMatches per season: [verified figure].',
    'packages', E'Package: {package_name}\n\nThis package covers {sponsor_name}''s brand on the club''s playing kit for {duration}.\n\n[Describe placement: front of shirt, sleeve, shorts, training kit.]',
    'benefits', E'{benefits}\n\nSuggested benefits for the Kit sponsor type:\n- Logo on the match shirt at [placement]\n- Mention in match announcements and club posts\n- Logo on the club website''s sponsors page\n- Recognition at club events\n- Photos of the team in the sponsor''s kit for their own use',
    'investment', E'The investment for {package_name} is {amount} for {duration}.\n\n[Add payment schedule and whether in-kind support is accepted.]',
    'terms', E'- The sponsorship runs for {duration} from the signing date.\n- Payment is made as agreed in the schedule, to the club''s official account.\n- The club will display the sponsor''s logo only after the sponsor approves the artwork.\n- Either party may end the agreement with [notice period] written notice.\n- A signed agreement will be completed before the sponsorship starts.',
    'next_steps', E'To go ahead, please contact {club_contact}. We will arrange a short meeting, confirm the kit placement, and prepare the agreement.\n\nThank you for considering a partnership with Timau Union FC.',
    '_verification', jsonb_build_object('achievements',false,'audience_reach',false)
  );

  insert into private.sponsor_proposal_templates
    (name,template_kind,sections,is_starter,status,created_by,updated_by)
  values
    ('Kit Sponsor Proposal','kit_sponsor',seed_sections,true,'draft',seed_user,seed_user)
  returning id into seed_id;

  insert into private.sponsor_workspace_audit
    (actor_user_id,record_table,record_id,action_key,after_data,reason)
  values
    (seed_user,'sponsor_proposal_templates',seed_id,'template_seeded',
     jsonb_build_object('name','Kit Sponsor Proposal','template_kind','kit_sponsor','status','draft','is_starter',true,'sections',seed_sections),
     'One-time idempotent starter seed. No unverified figures or achievements have been added.');
end
$seed$;

-- Server-side guard: client controls are helpful, but cannot be the security boundary.
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

 if _status in ('approved','sent') and exists (
   select 1 from private.sponsor_proposals p
   where p.id=_id and p.content_html ~ E'\\[[^][]+\\]'
 ) then
   raise exception 'Cannot approve or send this proposal while bracketed placeholders remain';
 end if;

 -- State machine: draft -> approved -> sent -> accepted|declined.
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

revoke all on function public.sponsor_proposal_set_status(uuid,text,text) from public,anon;
grant execute on function public.sponsor_proposal_set_status(uuid,text,text) to authenticated;

commit;

-- Restrict the three named starter proposal templates to Sponsor Lead and platform admins,
-- and seed Community Partner Proposal as a private draft.
begin;

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
 'templates',case when lead then coalesce((select jsonb_agg(to_jsonb(t) order by t.is_starter desc,t.name) from private.sponsor_proposal_templates t where lower(btrim(t.name)) not in ('kit sponsor proposal','match day sponsor proposal','community partner proposal') or admin or 'sponsor_lead'=any(r)),'[]'::jsonb) else '[]'::jsonb end,
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
 if lower(btrim(_name)) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal') and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can create these restricted starter templates';
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
 if (lower(btrim(coalesce(old_j->>'name',''))) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal') or lower(btrim(coalesce(_name,''))) in ('kit sponsor proposal','match day sponsor proposal','community partner proposal'))
    and not (admin or 'sponsor_lead'=any(r)) then
   raise exception 'Only Sponsor Lead or admin can view or edit these restricted starter templates';
 end if;
 update private.sponsor_proposal_templates set name=_name,template_kind=_kind,sections=_sections,updated_by=auth.uid(),updated_at=now() where id=_id;
 select to_jsonb(t) into new_j from private.sponsor_proposal_templates t where id=_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_proposal_templates',_id,case when admin then 'admin_override' else 'template_updated' end,old_j,new_j,_reason);
end $sponsor_template_update$;
revoke all on function public.sponsor_template_update(uuid,text,text,jsonb,text) from public,anon;
grant execute on function public.sponsor_template_update(uuid,text,text,jsonb,text) to authenticated;

-- One-time, safe seed for Community Partner Proposal. Never overwrite an existing row.
do $seed$
declare
  seed_user uuid;
  seed_id uuid;
  seed_sections jsonb;
begin
  select u.id into seed_user from auth.users u order by u.created_at, u.id limit 1;
  if seed_user is null then
    raise notice 'Community Partner Proposal seed skipped: no auth user exists to own the draft';
    return;
  end if;

  if exists (
    select 1 from private.sponsor_proposal_templates t
    where lower(btrim(t.name)) = 'community partner proposal'
  ) then
    raise notice 'Community Partner Proposal already exists; seed skipped without modifying it';
    return;
  end if;

  seed_sections := jsonb_build_object(
    'cover', E'COMMUNITY PARTNERSHIP PROPOSAL\nPrepared for {sponsor_name}\nAttention: {contact_person}\nTimau Union FC, {date}',
    'about_club', E'Timau Union FC is a community football club based in Timau, Meru County, competing in the Meru County League. We bring together local players and supporters, and we create opportunities for young people through football.\n\n[Add year founded, number of players, and any youth or community programs.]',
    'achievements', E'- Second place in the zone and playoff qualification in the 2025 Meru County League.\n- Second place in the zone and playoff qualification in the 2026 Meru County League.\n- [Add other verified achievements or community activities.]',
    'audience_reach', E'The club is followed by players, families, supporters and local businesses across Timau and nearby communities.\n\nTypical match attendance: [verified figure].\nSocial media followers: [verified figure].\nPlayers and officials: [verified figure].',
    'packages', E'Package: {package_name}\n\nThis package makes {sponsor_name} a community partner of Timau Union FC for {duration}. Support can be given as money, goods or services.\n\n[Describe what the partner will support: training costs, equipment, transport, match day costs, youth development.]',
    'benefits', E'{benefits}\n\nSuggested benefits for the Community partner type:\n- Recognition as a community partner on the club website''s sponsors page\n- Thank-you posts on the club''s social media at [frequency]\n- Name or logo on the partners board at [location] or at match days\n- Mention in match announcements\n- Invitation to selected matches and club events\n- Opportunity to hold a community activity or promotion with the club, agreed in advance\n- A photo with the team, for the partner''s own use',
    'investment', E'Community partners support the club at {amount} for {duration}, or through in-kind support such as [equipment / transport / refreshments / services] valued at [agreed value].\n\n[Add payment schedule, if any.]',
    'terms', E'- The partnership runs for {duration} from the signing date.\n- Money is paid to the club''s official account as agreed. In-kind support is recorded with an agreed value and a receiving official.\n- The club will display the partner''s name and logo only after the partner approves the artwork.\n- The club will not share photos of players under 18 for promotional use without the consent of a parent or guardian.\n- Either party may end the partnership with [notice period] written notice.\n- A short agreement will be signed before the partnership starts.',
    'next_steps', E'To become a community partner, please contact {club_contact}. We will agree how you would like to support the club, confirm the recognition you will receive, and prepare a short agreement.\n\nThank you for supporting football in our community.',
    '_verification', jsonb_build_object('achievements',false,'audience_reach',false)
  );

  insert into private.sponsor_proposal_templates
    (name,template_kind,sections,is_starter,status,created_by,updated_by)
  values
    ('Community Partner Proposal','community_partner',seed_sections,true,'draft',seed_user,seed_user)
  returning id into seed_id;

  insert into private.sponsor_workspace_audit
    (actor_user_id,record_table,record_id,action_key,after_data,reason)
  values
    (null,'sponsor_proposal_templates',seed_id,'template_seeded',
     jsonb_build_object('name','Community Partner Proposal','template_kind','community_partner','status','draft','is_starter',true,'sections',seed_sections),
     'One-time idempotent starter seed. No unverified figures or achievements have been added.');
end
$seed$;

commit;

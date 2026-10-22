-- Prospect evaluation and proposal templates for Sponsor Lead.
-- Depends on 20261022210000_sponsor_lead_workspace.sql. Candidate only; test before production.
begin;

create table if not exists private.sponsor_evaluation_settings (
 id boolean primary key default true check(id),
 weights jsonb not null default '{"club_fit":15,"financial_capacity":20,"local_relevance":15,"giving_history":10,"decision_access":10,"estimated_value":15,"closing_likelihood":15}'::jsonb,
 restricted_categories text[] not null default '{}',
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now()
);
insert into private.sponsor_evaluation_settings(id) values(true) on conflict(id) do nothing;

create table if not exists private.sponsor_prospect_evaluations (
 id uuid primary key default gen_random_uuid(),
 prospect_id uuid not null references private.sponsor_prospects(id) on delete cascade,
 scores jsonb not null default '{}'::jsonb,
 weights jsonb not null default '{}'::jsonb,
 weighted_score numeric(5,2) not null default 0 check(weighted_score between 0 and 100),
 rating_band text not null default 'weak' check(rating_band in ('strong','medium','weak')),
 reputation_risk boolean not null default false, reputation_notes text not null default '',
 sponsor_conflict boolean not null default false, conflict_notes text not null default '',
 restricted_category boolean not null default false, restricted_notes text not null default '',
 youth_risk boolean not null default false, youth_notes text not null default '',
 decision text not null default 'hold' check(decision in ('pursue','hold','decline')),
 decision_reason text not null default '',
 chairman_approved_by uuid references auth.users(id), chairman_approved_at timestamptz,
 evaluated_by uuid not null references auth.users(id), evaluated_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
create index if not exists sponsor_eval_prospect_date_idx on private.sponsor_prospect_evaluations(prospect_id,evaluated_at desc);

create table if not exists private.sponsor_proposal_templates (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(btrim(name)) between 2 and 160),
 template_kind text not null check(template_kind in ('kit_sponsor','match_day_sponsor','community_partner','custom')),
 sections jsonb not null default '{}'::jsonb,
 is_starter boolean not null default false,
 created_by uuid not null references auth.users(id),
 updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists private.sponsor_proposals (
 id uuid primary key default gen_random_uuid(),
 prospect_id uuid not null references private.sponsor_prospects(id) on delete restrict,
 package_id uuid references private.sponsor_packages(id) on delete set null,
 agreement_id uuid references private.sponsor_agreements(id) on delete set null,
 template_id uuid references private.sponsor_proposal_templates(id) on delete set null,
 title text not null,
 content_html text not null default '',
 amount_kes numeric(14,2) check(amount_kes is null or amount_kes>=0),
 duration text not null default '',
 status text not null default 'draft' check(status in ('draft','approved','sent','accepted','declined')),
 sent_at timestamptz, sent_by uuid references auth.users(id), follow_up_date date,
 approved_by uuid references auth.users(id), approved_at timestamptz,
 created_by uuid not null references auth.users(id), updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists private.sponsor_proposal_versions (
 id bigint generated always as identity primary key,
 proposal_id uuid not null references private.sponsor_proposals(id) on delete cascade,
 version_no integer not null,
 content_html text not null,
 status text not null,
 changed_by uuid not null references auth.users(id),
 changed_at timestamptz not null default now(),
 unique(proposal_id,version_no)
);

do $$ declare t text; begin
 foreach t in array array['sponsor_evaluation_settings','sponsor_prospect_evaluations','sponsor_proposal_templates','sponsor_proposals','sponsor_proposal_versions'] loop
  execute format('alter table private.%I enable row level security',t);
  execute format('revoke all on private.%I from public,anon,authenticated',t);
 end loop;
end $$;

create or replace function private.sponsor_eval_can_manage()
returns boolean language sql stable security definer set search_path=''
as $$ select auth.uid() is not null and (private.is_active_platform_admin(auth.uid()) or 'chairman'=any(private.current_club_roles()) or 'sponsor_lead'=any(private.current_club_roles())) $$;
revoke all on function private.sponsor_eval_can_manage() from public,anon,authenticated;

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
 'templates',case when lead then coalesce((select jsonb_agg(to_jsonb(t) order by t.is_starter desc,t.name) from private.sponsor_proposal_templates t),'[]'::jsonb) else '[]'::jsonb end,
 'proposals',case when lead then coalesce((select jsonb_agg(to_jsonb(p) order by p.updated_at desc) from private.sponsor_proposals p),'[]'::jsonb)
 when treasurer then coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'prospect_id',p.prospect_id,'title',p.title,'amount_kes',p.amount_kes,'status',p.status,'duration',p.duration) order by p.updated_at desc) from private.sponsor_proposals p),'[]'::jsonb) else '[]'::jsonb end,
 'proposal_versions',case when lead then coalesce((select jsonb_agg(to_jsonb(v) order by v.changed_at desc) from private.sponsor_proposal_versions v),'[]'::jsonb) else '[]'::jsonb end
 );
end $$;
revoke all on function public.sponsor_eval_get_workspace() from public,anon;
grant execute on function public.sponsor_eval_get_workspace() to authenticated;

create or replace function public.sponsor_eval_save_settings(_weights jsonb,_restricted_categories text[])
returns void language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; total numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r)) then raise exception 'Chairman or admin required'; end if;
 if jsonb_typeof(_weights)<>'object' or (_weights ?| array['club_fit','financial_capacity','local_relevance','giving_history','decision_access','estimated_value','closing_likelihood']) is false then raise exception 'All seven weight keys are required'; end if;
 if exists(select 1 from jsonb_each_text(_weights) x where x.key not in ('club_fit','financial_capacity','local_relevance','giving_history','decision_access','estimated_value','closing_likelihood') or x.value !~ '^[0-9]+(\\.[0-9]+)?$' or x.value::numeric<0 or x.value::numeric>100) then raise exception 'Weights must be numbers from 0 to 100'; end if;
 total:=coalesce((select sum(value::numeric) from jsonb_each_text(_weights)),0);
 if abs(total-100)>0.01 then raise exception 'Weights must total 100 percent'; end if;
 insert into private.sponsor_evaluation_settings(id,weights,restricted_categories,updated_by,updated_at) values(true,_weights,coalesce(_restricted_categories,'{}'),auth.uid(),now())
 on conflict(id) do update set weights=excluded.weights,restricted_categories=excluded.restricted_categories,updated_by=excluded.updated_by,updated_at=now();
end $$;
revoke all on function public.sponsor_eval_save_settings(jsonb,text[]) from public,anon;
grant execute on function public.sponsor_eval_save_settings(jsonb,text[]) to authenticated;

create or replace function public.sponsor_eval_save(_prospect_id uuid,_scores jsonb,_risks jsonb,_decision text,_reason text,_chairman_approval boolean default false)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; chairman boolean; w jsonb; score numeric:=0; total_weight numeric:=0; k text; v numeric; band text; risk boolean; rid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid()); chairman:=admin or 'chairman'=any(r);
 if not private.sponsor_eval_can_manage() then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if _decision not in ('pursue','hold','decline') then raise exception 'Invalid decision'; end if;
 if not exists(select 1 from private.sponsor_prospects p where p.id=_prospect_id) then raise exception 'Prospect not found'; end if;
 select weights into w from private.sponsor_evaluation_settings where id=true;
 if jsonb_typeof(_scores)<>'object' then raise exception 'Scores object required'; end if;
 foreach k in array array['club_fit','financial_capacity','local_relevance','giving_history','decision_access','estimated_value','closing_likelihood'] loop
  if not (_scores ? k) or (_scores->>k) !~ '^[1-5]$' then raise exception 'Each score must be 1-5'; end if;
  v:=(_scores->>k)::numeric; score:=score+v*(w->>k)::numeric; total_weight:=total_weight+(w->>k)::numeric;
 end loop;
 if total_weight<=0 then raise exception 'Weights must sum to a positive value'; end if;
 score:=round((score/(5*total_weight))*100,2);
 band:=case when score>=75 then 'strong' when score>=50 then 'medium' else 'weak' end;
 risk:=coalesce((_risks->>'reputation_risk')::boolean,false) or coalesce((_risks->>'sponsor_conflict')::boolean,false) or coalesce((_risks->>'restricted_category')::boolean,false) or coalesce((_risks->>'youth_risk')::boolean,false);
 if _decision='pursue' and risk and not chairman then raise exception 'Risk-flagged prospect requires Chairman approval before pursuing'; end if;
 insert into private.sponsor_prospect_evaluations(prospect_id,scores,weights,weighted_score,rating_band,reputation_risk,reputation_notes,sponsor_conflict,conflict_notes,restricted_category,restricted_notes,youth_risk,youth_notes,decision,decision_reason,chairman_approved_by,chairman_approved_at,evaluated_by)
 values(_prospect_id,_scores,w,score,band,coalesce((_risks->>'reputation_risk')::boolean,false),coalesce(_risks->>'reputation_notes',''),coalesce((_risks->>'sponsor_conflict')::boolean,false),coalesce(_risks->>'conflict_notes',''),coalesce((_risks->>'restricted_category')::boolean,false),coalesce(_risks->>'restricted_notes',''),coalesce((_risks->>'youth_risk')::boolean,false),coalesce(_risks->>'youth_notes',''),_decision,coalesce(_reason,''),case when _decision='pursue' and risk and chairman then auth.uid() end,case when _decision='pursue' and risk and chairman then now() end,auth.uid()) returning id into rid;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data,reason) values(auth.uid(),'sponsor_prospect_evaluations',rid,'evaluation_created',jsonb_build_object('prospect_id',_prospect_id,'scores',_scores,'weights',w,'weighted_score',score,'rating_band',band,'risks',_risks,'decision',_decision),_reason);
 return rid;
end $$;
revoke all on function public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean) from public,anon;
grant execute on function public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean) to authenticated;

create or replace function public.sponsor_proposal_save(_id uuid,_prospect_id uuid,_package_id uuid,_template_id uuid,_title text,_content_html text,_amount_kes numeric,_duration text,_follow_up_date date)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; rid uuid; old_j jsonb; vno integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not private.sponsor_eval_can_manage() then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if _id is null then
  insert into private.sponsor_proposals(prospect_id,package_id,template_id,title,content_html,amount_kes,duration,follow_up_date,created_by,updated_by)
  values(_prospect_id,_package_id,_template_id,_title,_content_html,_amount_kes,coalesce(_duration,''),_follow_up_date,auth.uid(),auth.uid()) returning id into rid;
 else
  select to_jsonb(p) into old_j from private.sponsor_proposals p where id=_id for update;
  if old_j is null then raise exception 'Proposal not found'; end if;
  if old_j->>'status' in ('sent','accepted','declined') and not (admin or 'chairman'=any(r)) then raise exception 'Only Chairman or admin can change a finalized proposal'; end if;
  update private.sponsor_proposals set prospect_id=_prospect_id,package_id=_package_id,template_id=_template_id,title=_title,content_html=_content_html,amount_kes=_amount_kes,duration=coalesce(_duration,''),follow_up_date=_follow_up_date,updated_by=auth.uid(),updated_at=now(),status=case when status='approved' then 'draft' else status end where id=_id returning id into rid;
 end if;
 select coalesce(max(version_no),0)+1 into vno from private.sponsor_proposal_versions where proposal_id=rid;
 insert into private.sponsor_proposal_versions(proposal_id,version_no,content_html,status,changed_by) values(rid,vno,_content_html,'draft',auth.uid());
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason) values(auth.uid(),'sponsor_proposals',rid,case when _id is null then 'proposal_created' else 'proposal_version_saved' end,old_j,jsonb_build_object('title',_title,'content_html',_content_html,'amount_kes',_amount_kes,'status','draft','version_no',vno),null);
 return rid;
end $$;
revoke all on function public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date) from public,anon;
grant execute on function public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date) to authenticated;

create or replace function public.sponsor_proposal_set_status(_id uuid,_status text,_reason text default null)
returns void language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; chairman boolean; old_j jsonb; new_j jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid()); chairman:=admin or 'chairman'=any(r);
 if not private.sponsor_eval_can_manage() then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if _status not in ('approved','sent','accepted','declined') then raise exception 'Invalid proposal status'; end if;
 if _status in ('approved','sent','accepted','declined') and not chairman then raise exception 'Chairman or admin approval required'; end if;
 select to_jsonb(p) into old_j from private.sponsor_proposals p where id=_id for update;
 if old_j is null then raise exception 'Proposal not found'; end if;
 update private.sponsor_proposals set status=_status,approved_by=case when _status='approved' then auth.uid() else approved_by end,approved_at=case when _status='approved' then now() else approved_at end,sent_at=case when _status='sent' then now() else sent_at end,sent_by=case when _status='sent' then auth.uid() else sent_by end,updated_by=auth.uid(),updated_at=now() where id=_id;
 select to_jsonb(p) into new_j from private.sponsor_proposals p where id=_id;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason) values(auth.uid(),'sponsor_proposals',_id,case when admin then 'admin_override' else 'proposal_status_changed' end,old_j,new_j,_reason);
end $$;
revoke all on function public.sponsor_proposal_set_status(uuid,text,text) from public,anon;
grant execute on function public.sponsor_proposal_set_status(uuid,text,text) to authenticated;

-- Starter templates contain placeholders only, never fabricated club facts or statistics.
insert into private.sponsor_proposal_templates(name,template_kind,sections,is_starter,created_by,updated_by)
select x.name,x.kind,x.sections,true,x.uid,x.uid from (
 select 'Kit sponsor'::text name,'kit_sponsor'::text kind,
 jsonb_build_object('cover','Sponsorship proposal for {sponsor_name}','about_club','[Enter verified club history]','achievements','[Enter achievements marked verified]','audience_reach','[Enter verified audience and reach]','packages','Kit sponsorship: {package_name}','benefits','{benefits}','investment','Investment: {amount}; Duration: {duration}','terms','[Enter proposed terms]','next_steps','Contact: {club_contact}; Date: {date}') sections,(select id from auth.users order by created_at limit 1) uid
 union all select 'Match day sponsor','match_day_sponsor',jsonb_build_object('cover','Match day sponsorship proposal for {sponsor_name}','about_club','[Enter verified club history]','achievements','[Enter verified achievements]','audience_reach','[Enter verified audience and reach]','packages','{package_name}','benefits','{benefits}','investment','{amount} for {duration}','terms','[Enter proposed terms]','next_steps','{club_contact} · {date}'),(select id from auth.users order by created_at limit 1)
 union all select 'Community partner','community_partner',jsonb_build_object('cover','Community partnership proposal for {sponsor_name}','about_club','[Enter verified club history]','achievements','[Enter verified achievements]','audience_reach','[Enter verified audience and reach]','packages','{package_name}','benefits','{benefits}','investment','{amount} · {duration}','terms','[Enter proposed terms]','next_steps','{club_contact} · {date}'),(select id from auth.users order by created_at limit 1)
) x where x.uid is not null and not exists(select 1 from private.sponsor_proposal_templates t where t.name=x.name and t.is_starter=true);

commit;

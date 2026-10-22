-- Correct evaluation insert column/value alignment in the Sponsor Lead security migration.
begin;
create or replace function public.sponsor_eval_save(_prospect_id uuid,_scores jsonb,_risks jsonb,_decision text,_reason text,_chairman_approval boolean default false)
returns uuid language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; chairman boolean; w jsonb; score numeric:=0; total_weight numeric:=0; k text; v numeric; band text; risk boolean; rid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid()); chairman:=admin or 'chairman'=any(r);
 if not private.sponsor_eval_can_manage() then raise exception 'Sponsor Lead, Chairman or admin required'; end if;
 if _decision not in ('pursue','hold','decline') then raise exception 'Invalid decision'; end if;
 if _risks is null or jsonb_typeof(_risks)<>'object' then raise exception 'Risk checks object required'; end if;
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
 if exists(select 1 from private.sponsor_prospects p cross join private.sponsor_evaluation_settings s where p.id=_prospect_id and s.id=true and lower(p.sponsor_category)=any(select lower(x) from unnest(s.restricted_categories) x)) then risk:=true; end if;

 insert into private.sponsor_prospect_evaluations(prospect_id,scores,weights,weighted_score,rating_band,reputation_risk,reputation_notes,sponsor_conflict,conflict_notes,restricted_category,restricted_notes,youth_risk,youth_notes,decision,requested_decision,approval_requested,decision_reason,chairman_approved_by,chairman_approved_at,evaluated_by)
 values(_prospect_id,_scores,w,score,band,coalesce((_risks->>'reputation_risk')::boolean,false),coalesce(_risks->>'reputation_notes',''),coalesce((_risks->>'sponsor_conflict')::boolean,false),coalesce(_risks->>'conflict_notes',''),coalesce((_risks->>'restricted_category')::boolean,false) or exists(select 1 from private.sponsor_prospects p cross join private.sponsor_evaluation_settings s where p.id=_prospect_id and s.id=true and lower(p.sponsor_category)=any(select lower(x) from unnest(s.restricted_categories) x)),case when exists(select 1 from private.sponsor_prospects p cross join private.sponsor_evaluation_settings s where p.id=_prospect_id and s.id=true and lower(p.sponsor_category)=any(select lower(x) from unnest(s.restricted_categories) x)) then concat_ws(' ',nullif(_risks->>'restricted_notes',''),'Automatically matched Chairman restricted-category settings.') else coalesce(_risks->>'restricted_notes','') end,coalesce((_risks->>'youth_risk')::boolean,false),coalesce(_risks->>'youth_notes',''),case when _decision='pursue' and risk and not chairman then 'hold' else _decision end,case when _decision='pursue' and risk and not chairman then 'pursue' end,(_decision='pursue' and risk and not chairman),case when _decision='pursue' and risk and not chairman then 'pursuit requested; Chairman approval required. '||coalesce(_reason,'') else coalesce(_reason,'') end,case when _decision='pursue' and risk and chairman then auth.uid() end,case when _decision='pursue' and risk and chairman then now() end,auth.uid()) returning id into rid;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data,reason) values(auth.uid(),'sponsor_prospect_evaluations',rid,'evaluation_created',jsonb_build_object('prospect_id',_prospect_id,'scores',_scores,'weights',w,'weighted_score',score,'rating_band',band,'risks',_risks,'decision',_decision),_reason);
 return rid;
end $$;
revoke all on function public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean) from public,anon;
grant execute on function public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean) to authenticated;
commit;

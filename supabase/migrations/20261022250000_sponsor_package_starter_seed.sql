-- Idempotent starter sponsorship packages. Values intentionally contain no invented prices or duration.
begin;
create or replace function public.sponsor_packages_seed_starters()
returns integer
language plpgsql
security definer
set search_path=''
as $$
declare
  r text[];
  admin boolean;
  n integer := 0;
  item jsonb;
  starters jsonb := jsonb_build_array(
    jsonb_build_object('name','Kit Sponsor Package','tier','kit','benefits','Logo on the match shirt at [placement]; mention in match announcements and club posts; logo on the club website''s sponsors page; recognition at club events; photos of the team in the sponsor''s kit for their own use.'),
    jsonb_build_object('name','Match Day Sponsor Package','tier','match_day','benefits','Match named after the sponsor; sponsor banner at the pitch at [placement]; sponsor announced at the match; mentions in pre-match and post-match social posts; logo on the sponsors page and fixtures listing; photo with the team; agreed promotion or product display at the match.'),
    jsonb_build_object('name','Training Sponsor Package','tier','training','benefits','Sponsor name or logo on the training kit or bibs at [placement]; recognition as the club''s training partner on the website; thank-you posts on social media at [frequency]; invitation to a training session; photo with the team.'),
    jsonb_build_object('name','Website and Social Media Package','tier','website_social','benefits','Logo and link on the club website''s sponsors page; sponsor feature post on social media at [frequency]; sponsor mention in match result posts; sponsor logo on match graphics.'),
    jsonb_build_object('name','Community Partner Package','tier','community_partner','benefits','Recognition as a community partner on the website; thank-you posts on social media at [frequency]; name or logo on the partners board at [location]; mention in match announcements; invitation to selected matches and events; agreed community activity with the club.'),
    jsonb_build_object('name','Custom Package','tier','other','benefits','[List the benefits agreed for this sponsor.]')
  );
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  r := private.current_club_roles();
  admin := private.is_active_platform_admin(auth.uid());
  if not (admin or 'chairman'=any(r) or 'sponsor_lead'=any(r)) then
    raise exception 'Sponsor Lead, Chairman or admin required';
  end if;
  perform pg_advisory_xact_lock(hashtext('timau_union_fc_sponsor_starter_packages'));
  for item in select value from jsonb_array_elements(starters)
  loop
    if not exists (
      select 1 from private.sponsor_packages p
      where lower(btrim(p.name))=lower(btrim(item->>'name'))
    ) then
      insert into private.sponsor_packages(name,tier,benefits,price_kes,in_kind_value,duration,status,created_by,updated_by)
      values(item->>'name',item->>'tier',item->>'benefits',null,null,'','draft',auth.uid(),auth.uid());
      n := n + 1;
      insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,after_data)
      select auth.uid(),'sponsor_packages',p.id,'starter_created',to_jsonb(p)
      from private.sponsor_packages p where lower(btrim(p.name))=lower(btrim(item->>'name'));
    end if;
  end loop;
  return n;
end $$;
revoke all on function public.sponsor_packages_seed_starters() from public, anon;
grant execute on function public.sponsor_packages_seed_starters() to authenticated;
commit;

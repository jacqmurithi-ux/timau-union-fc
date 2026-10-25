begin;
create table if not exists public.sponsor_page_content (
  singleton boolean primary key default true check (singleton),
  content jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
alter table public.sponsor_page_content enable row level security;
revoke all on public.sponsor_page_content from public, anon, authenticated;
insert into public.sponsor_page_content(singleton,content) values(true,
'{"hero_eyebrow":"Partnerships that move us forward","hero_title":"Back the badge. Build the future.","hero_description":"Support community football, connect with local fans and help Timau Union FC keep moving forward. Our Sponsor Lead will share package details after your enquiry.","section_eyebrow":"Ways to partner","section_title":"Find the right fit","section_intro":"Choose the area that best matches your business or organisation. Benefits, duration, price and delivery dates are agreed with the club before a package is confirmed. Examples below are options, not automatic guarantees.","next_title":"Let’s start a conversation","next_description":"Send a short enquiry with your contact details and the package you’re interested in. There’s no account to create and no commitment to sponsor.","packages":[{"key":"Kit","title":"Kit","description":"Help fund playing or training kit so the team can represent Timau with pride.","benefits":"Agreed logo or business-name placement on selected kit, subject to club approval\nRecognition in club updates and a team-kit thank-you\nTeam photos for agreed sponsor use"},{"key":"Match day","title":"Match day","description":"Help make a fixture or football event possible while introducing your business to local supporters.","benefits":"Sponsor acknowledgement in agreed pre-match and post-match posts\nRecognition on match posters and at the event where arrangements allow\nOptional banner, product display or photo opportunity by agreement"},{"key":"Training","title":"Training","description":"Support training equipment, sessions or player preparation throughout the season.","benefits":"Recognition as a training supporter on club channels\nAgreed name or logo placement on training bibs or equipment, where available\nThank-you post and an agreed training-session photo"},{"key":"Website / social","title":"Website / social","description":"Reach the club community through digital channels and approved sponsor content.","benefits":"Business name, logo and website link on the partners page, once approved\nAgreed sponsor feature or thank-you posts\nLogo or name on selected match graphics where suitable"},{"key":"Community partner","title":"Community partner","description":"Back community football and help the club create positive opportunities around Timau.","benefits":"Recognition as a community partner on the website, once approved\nAgreed thank-you posts and mentions in club announcements\nOpportunity to discuss a community activity or supporter offer with the club"},{"key":"Other","title":"Other","description":"Propose cash support, equipment, services, transport, refreshments or another practical contribution.","benefits":"Benefits tailored to the agreed support\nSuitable recognition discussed before anything is promised\nCash and in-kind contributions documented separately in the agreement"}]}'::jsonb) on conflict(singleton) do nothing;
create or replace function public.sponsor_page_content_get()
returns jsonb language sql stable security definer set search_path='' as $$
 select content from public.sponsor_page_content where singleton=true
$$;
revoke all on function public.sponsor_page_content_get() from public;
grant execute on function public.sponsor_page_content_get() to anon, authenticated;
create or replace function public.sponsor_page_content_save(_content jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare v_before jsonb;
begin
 if auth.uid() is null or not (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())) then
   raise exception 'Sponsor Lead or Platform Admin required to edit the public sponsorship page.' using errcode='42501';
 end if;
 if jsonb_typeof(_content)<>'object' or jsonb_typeof(_content->'packages')<>'array' or jsonb_array_length(_content->'packages')<>6 then
   raise exception 'Provide all six sponsorship packages and page content.' using errcode='22023';
 end if;
 if char_length(coalesce(_content->>'hero_eyebrow','')) not between 1 and 100 or char_length(coalesce(_content->>'hero_title','')) not between 2 and 140 or char_length(coalesce(_content->>'hero_description','')) not between 2 and 700 or char_length(coalesce(_content->>'section_eyebrow','')) not between 1 and 100 or char_length(coalesce(_content->>'section_title','')) not between 2 and 140 or char_length(coalesce(_content->>'section_intro','')) not between 2 and 700 or char_length(coalesce(_content->>'next_title','')) not between 2 and 140 or char_length(coalesce(_content->>'next_description','')) not between 2 and 700 then
   raise exception 'Check required page text and character limits.' using errcode='22023';
 end if;
 if exists(select 1 from jsonb_array_elements(_content->'packages') p where jsonb_typeof(p)<>'object' or coalesce(p->>'key','') not in ('Kit','Match day','Training','Website / social','Community partner','Other') or char_length(coalesce(p->>'title','')) not between 2 and 100 or char_length(coalesce(p->>'description','')) not between 2 and 700 or char_length(coalesce(p->>'benefits','')) not between 2 and 1200) then
   raise exception 'Each package needs a valid title, description and benefits.' using errcode='22023';
 end if;
 if (select count(distinct p->>'key') from jsonb_array_elements(_content->'packages') p)<>6 then raise exception 'Each of the six package types must appear exactly once.' using errcode='22023'; end if;
 select content into v_before from public.sponsor_page_content where singleton=true for update;
 insert into public.sponsor_page_content(singleton,content,updated_at,updated_by) values(true,_content,now(),auth.uid())
 on conflict(singleton) do update set content=excluded.content,updated_at=excluded.updated_at,updated_by=excluded.updated_by;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_page_content',null,'sponsor_public_page_content_updated',v_before,_content,'Public sponsorship page content edited from Sponsor Lead workspace');
end $$;
revoke all on function public.sponsor_page_content_save(jsonb) from public, anon;
grant execute on function public.sponsor_page_content_save(jsonb) to authenticated;
commit;
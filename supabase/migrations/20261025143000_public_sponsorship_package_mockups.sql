begin;
-- Public, read-only image delivery for the six sponsorship package cards.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('sponsor-public-mockups','sponsor-public-mockups',true,10485760,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=true,file_size_limit=10485760,allowed_mime_types=array['image/png','image/jpeg','image/webp'];

drop policy if exists "Sponsor leads upload public package mockups" on storage.objects;
create policy "Sponsor leads upload public package mockups" on storage.objects
for insert to authenticated
with check (bucket_id='sponsor-public-mockups' and (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())));

drop policy if exists "Sponsor leads update public package mockups" on storage.objects;
create policy "Sponsor leads update public package mockups" on storage.objects
for update to authenticated
using (bucket_id='sponsor-public-mockups' and (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())))
with check (bucket_id='sponsor-public-mockups' and (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())));

drop policy if exists "Sponsor leads delete public package mockups" on storage.objects;
create policy "Sponsor leads delete public package mockups" on storage.objects
for delete to authenticated
using (bucket_id='sponsor-public-mockups' and (private.is_active_platform_admin(auth.uid()) or 'sponsor_lead'=any(private.current_club_roles())));

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
 if exists(select 1 from jsonb_array_elements(_content->'packages') p where jsonb_typeof(p)<>'object' or coalesce(p->>'key','') not in ('Kit','Match day','Training','Website / social','Community partner','Other') or char_length(coalesce(p->>'title','')) not between 2 and 100 or char_length(coalesce(p->>'description','')) not between 2 and 700 or char_length(coalesce(p->>'benefits','')) not between 2 and 1200 or (coalesce(p->>'image_url','')<>'' and (length(p->>'image_url')>700 or (p->>'image_url') not like 'https://owvvimydkjsjlrmnzvdi.supabase.co/storage/v1/object/public/sponsor-public-mockups/%'))) then
   raise exception 'Each package needs valid text and any image must use the public sponsorship mockup bucket.' using errcode='22023';
 end if;
 if (select count(distinct p->>'key') from jsonb_array_elements(_content->'packages') p)<>6 then raise exception 'Each of the six package types must appear exactly once.' using errcode='22023'; end if;
 select content into v_before from public.sponsor_page_content where singleton=true for update;
 insert into public.sponsor_page_content(singleton,content,updated_at,updated_by) values(true,_content,now(),auth.uid())
 on conflict(singleton) do update set content=excluded.content,updated_at=excluded.updated_at,updated_by=excluded.updated_by;
 insert into private.sponsor_workspace_audit(actor_user_id,record_table,record_id,action_key,before_data,after_data,reason)
 values(auth.uid(),'sponsor_page_content',null,'sponsor_public_page_content_updated',v_before,_content,'Public sponsorship page content and package mockups edited from Sponsor Lead workspace');
end $$;
revoke all on function public.sponsor_page_content_save(jsonb) from public, anon;
grant execute on function public.sponsor_page_content_save(jsonb) to authenticated;
commit;

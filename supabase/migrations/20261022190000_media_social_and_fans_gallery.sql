-- Media Team social publishing, analytics and Fans Gallery.
-- Apply to Union Test first; production rollout requires migration review and role-based verification.
begin;

create table public.social_posts (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 240),
  copy_text text not null default '' check (length(copy_text) <= 10000),
  channel text not null check (channel in ('Facebook','Instagram','X','TikTok','YouTube','WhatsApp channel')),
  planned_for date,
  status text not null default 'idea' check (status in ('idea','drafted','approved','posted')),
  post_url text check (post_url is null or length(post_url) <= 2000),
  reach bigint not null default 0 check (reach >= 0),
  impressions bigint not null default 0 check (impressions >= 0),
  likes bigint not null default 0 check (likes >= 0),
  comments bigint not null default 0 check (comments >= 0),
  shares bigint not null default 0 check (shares >= 0),
  saves bigint not null default 0 check (saves >= 0),
  link_clicks bigint not null default 0 check (link_clicks >= 0),
  followers_gained bigint not null default 0 check (followers_gained >= 0),
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  constraint social_posts_approval_consistency check (
    (status in ('approved','posted') and approved_by is not null and approved_at is not null)
    or status in ('idea','drafted')
  )
);
create index social_posts_calendar_idx on public.social_posts(planned_for, channel, status);
create index social_posts_creator_idx on public.social_posts(created_by, updated_at desc);
alter table public.social_posts enable row level security;
revoke all on public.social_posts from public, anon, authenticated;

create table public.fan_gallery (
  id uuid primary key default gen_random_uuid(),
  image_path text not null unique check (length(image_path) <= 1000),
  caption text check (caption is null or length(caption) <= 1000),
  fixture_url text check (fixture_url is null or length(fixture_url) <= 2000),
  photo_date date not null,
  alt_text text not null check (length(btrim(alt_text)) between 5 and 300),
  order_index integer not null default 0,
  status text not null default 'draft' check (status in ('draft','approved')),
  consent_confirmed boolean not null default false,
  identifiable_children boolean not null default false,
  child_consent_confirmed boolean not null default false,
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  constraint fan_gallery_approval_consent check (
    status <> 'approved' or
    (consent_confirmed and (not identifiable_children or child_consent_confirmed)
     and approved_by is not null and approved_at is not null)
  )
);
create index fan_gallery_public_order_idx on public.fan_gallery(status, order_index, photo_date desc);
alter table public.fan_gallery enable row level security;
revoke all on public.fan_gallery from public, anon, authenticated;
revoke select on public.fan_gallery from anon, authenticated;
grant select (id,image_path,caption,fixture_url,photo_date,alt_text,order_index,status) on public.fan_gallery to anon, authenticated;

create table private.media_record_audit (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  record_id uuid,
  record_type text not null check (record_type in ('social_post','fan_gallery')),
  action_key text not null,
  reason text,
  is_admin_override boolean not null default false,
  old_data jsonb not null default '{}'::jsonb,
  new_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index media_record_audit_record_idx on private.media_record_audit(record_type, record_id, created_at desc);
alter table private.media_record_audit enable row level security;
revoke all on private.media_record_audit from public, anon, authenticated;

-- Small, explicit role predicate used by RLS and RPCs. It relies on the
-- existing approved access + confirmed email + active role-assignment model.
create or replace function public.media_can_manage()
returns boolean
language sql stable security definer set search_path=''
as $function$
  select auth.uid() is not null and (
    private.is_active_platform_admin(auth.uid())
    or 'media_team' = any(private.current_club_roles())
  )
$function$;
revoke all on function public.media_can_manage() from public, anon;
grant execute on function public.media_can_manage() to authenticated;

create policy social_posts_media_read on public.social_posts
for select to authenticated using (public.media_can_manage());
grant select on public.social_posts to authenticated;

create policy fan_gallery_public_approved_read on public.fan_gallery
for select to anon, authenticated using (status = 'approved');
create policy fan_gallery_media_read on public.fan_gallery
for select to authenticated using (public.media_can_manage());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('fans-gallery','fans-gallery',false,8388608,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create policy fans_gallery_public_approved_image_read on storage.objects
for select to anon, authenticated
using (
  bucket_id = 'fans-gallery'
  and exists (
    select 1 from public.fan_gallery g
    where g.image_path = storage.objects.name and g.status = 'approved'
  )
);
create policy fans_gallery_media_read_all on storage.objects
for select to authenticated using (bucket_id = 'fans-gallery' and public.media_can_manage());
create policy fans_gallery_media_upload on storage.objects
for insert to authenticated with check (bucket_id = 'fans-gallery' and public.media_can_manage());
create policy fans_gallery_media_update on storage.objects
for update to authenticated using (bucket_id = 'fans-gallery' and public.media_can_manage())
with check (bucket_id = 'fans-gallery' and public.media_can_manage());
create policy fans_gallery_media_delete on storage.objects
for delete to authenticated using (bucket_id = 'fans-gallery' and public.media_can_manage());

create or replace function public.media_get_workspace()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v_admin boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then
    raise exception 'Media Team or Platform Admin access required';
  end if;
  v_admin := private.is_active_platform_admin(auth.uid());
  return jsonb_build_object(
    'is_platform_admin',v_admin,
    'roles',to_jsonb(private.current_club_roles()),
    'posts',coalesce((select jsonb_agg(to_jsonb(p) order by p.planned_for nulls last,p.updated_at desc) from public.social_posts p),'[]'::jsonb),
    'photos',coalesce((select jsonb_agg(to_jsonb(g) order by g.order_index,g.photo_date desc,g.created_at desc) from public.fan_gallery g),'[]'::jsonb)
  );
end $function$;
revoke all on function public.media_get_workspace() from public, anon;
grant execute on function public.media_get_workspace() to authenticated;

create or replace function public.media_save_social_post(
  _record_id uuid, _title text, _copy_text text, _channel text,
  _planned_for date, _post_url text, _status text, _reason text
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.social_posts%rowtype; v_id uuid; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if _title is null or length(btrim(_title)) not between 1 and 240 or coalesce(length(_copy_text),0)>10000 then raise exception 'Title or copy is invalid'; end if;
  if _channel not in ('Facebook','Instagram','X','TikTok','YouTube','WhatsApp channel') then raise exception 'Unsupported channel'; end if;
  if _status not in ('idea','drafted') then raise exception 'New or edited posts must be saved as idea or drafted'; end if;
  if _post_url is not null and length(_post_url)>2000 then raise exception 'Post link is too long'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  if _record_id is null then
    insert into public.social_posts(title,copy_text,channel,planned_for,post_url,status,created_by,updated_by)
    values(btrim(_title),coalesce(_copy_text,''),_channel,_planned_for,nullif(btrim(_post_url),''),_status,auth.uid(),auth.uid())
    returning id into v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,new_data)
    values(auth.uid(),v_id,'social_post','created',jsonb_build_object('title',_title,'channel',_channel,'status',_status));
  else
    select * into v_old from public.social_posts where id=_record_id for update;
    if not found then raise exception 'Social post not found'; end if;
    v_override:=v_admin and v_old.created_by<>auth.uid();
    if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
    update public.social_posts set title=btrim(_title),copy_text=coalesce(_copy_text,''),channel=_channel,
      planned_for=_planned_for,post_url=nullif(btrim(_post_url),''),status=_status,
      approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now()
    where id=_record_id returning id into v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
    values(auth.uid(),v_id,'social_post',case when v_override then 'admin_override_updated' else 'updated_reset_to_draft' end,
      nullif(btrim(_reason),''),v_override,to_jsonb(v_old),jsonb_build_object('title',_title,'copy_text',_copy_text,'channel',_channel,'planned_for',_planned_for,'post_url',_post_url,'status',_status));
  end if;
  return v_id;
end $function$;
revoke all on function public.media_save_social_post(uuid,text,text,text,date,text,text,text) from public, anon;
grant execute on function public.media_save_social_post(uuid,text,text,text,date,text,text,text) to authenticated;

create or replace function public.media_set_social_status(_record_id uuid,_new_status text,_reason text)
returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.social_posts%rowtype; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if _new_status not in ('approved','drafted','posted') then raise exception 'Invalid social post status'; end if;
  select * into v_old from public.social_posts where id=_record_id for update;
  if not found then raise exception 'Social post not found'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  if not v_admin and v_old.created_by<>auth.uid() then raise exception 'Media Team members may approve their own social posts'; end if;
  if _new_status='approved' and v_old.status not in ('drafted','approved') then raise exception 'Save the post as drafted before approval'; end if;
  if _new_status='posted' and v_old.status<>'approved' then raise exception 'Approve the post before marking it posted'; end if;
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.social_posts set status=_new_status,
    approved_by=case when _new_status in ('approved','posted') then coalesce(approved_by,auth.uid()) else null end,
    approved_at=case when _new_status in ('approved','posted') then coalesce(approved_at,now()) else null end,
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'social_post','status_'||_new_status,nullif(btrim(_reason),''),v_override,
    jsonb_build_object('status',v_old.status),jsonb_build_object('status',_new_status,'approved_by',case when _new_status in ('approved','posted') then auth.uid() else null end));
  return true;
end $function$;
revoke all on function public.media_set_social_status(uuid,text,text) from public, anon;
grant execute on function public.media_set_social_status(uuid,text,text) to authenticated;

create or replace function public.media_save_social_stats(
  _record_id uuid,_reach bigint,_impressions bigint,_likes bigint,_comments bigint,
  _shares bigint,_saves bigint,_link_clicks bigint,_followers_gained bigint,_post_url text,_reason text
) returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.social_posts%rowtype; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if least(_reach,_impressions,_likes,_comments,_shares,_saves,_link_clicks,_followers_gained)<0 then raise exception 'Stats cannot be negative'; end if;
  select * into v_old from public.social_posts where id=_record_id for update;
  if not found then raise exception 'Social post not found'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.social_posts set reach=_reach,impressions=_impressions,likes=_likes,comments=_comments,shares=_shares,
    saves=_saves,link_clicks=_link_clicks,followers_gained=_followers_gained,post_url=nullif(btrim(_post_url),''),
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'social_post','stats_updated',nullif(btrim(_reason),''),v_override,
    jsonb_build_object('reach',v_old.reach,'impressions',v_old.impressions,'likes',v_old.likes,'comments',v_old.comments,'shares',v_old.shares,'saves',v_old.saves,'link_clicks',v_old.link_clicks,'followers_gained',v_old.followers_gained,'post_url',v_old.post_url),
    jsonb_build_object('reach',_reach,'impressions',_impressions,'likes',_likes,'comments',_comments,'shares',_shares,'saves',_saves,'link_clicks',_link_clicks,'followers_gained',_followers_gained,'post_url',_post_url));
  return true;
end $function$;
revoke all on function public.media_save_social_stats(uuid,bigint,bigint,bigint,bigint,bigint,bigint,bigint,bigint,text,text) from public, anon;
grant execute on function public.media_save_social_stats(uuid,bigint,bigint,bigint,bigint,bigint,bigint,bigint,bigint,text,text) to authenticated;

create or replace function public.media_save_fan_photo(
  _record_id uuid,_image_path text,_caption text,_fixture_url text,_photo_date date,_alt_text text,
  _identifiable_children boolean,_reason text
) returns uuid language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.fan_gallery%rowtype; v_id uuid; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if _image_path is null or length(btrim(_image_path))<5 or _photo_date is null or length(btrim(coalesce(_alt_text,''))) not between 5 and 300 then raise exception 'Image, date and descriptive alt text are required'; end if;
  if split_part(_image_path,'/',1)='' or _image_path like '/%' or _image_path like '%..%' then raise exception 'Invalid storage path'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='fans-gallery' and o.name=_image_path) then raise exception 'Uploaded photo must exist in the Fans Gallery bucket'; end if;
  if _caption is not null and length(_caption)>1000 then raise exception 'Caption too long'; end if;
  if _fixture_url is not null and length(_fixture_url)>2000 then raise exception 'Fixture link too long'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  if _record_id is null then
    if split_part(_image_path,'/',1)<>auth.uid()::text then raise exception 'New photos must be uploaded to your own folder'; end if;
    insert into public.fan_gallery(image_path,caption,fixture_url,photo_date,alt_text,identifiable_children,created_by,updated_by)
    values(_image_path,nullif(btrim(_caption),''),nullif(btrim(_fixture_url),''),_photo_date,btrim(_alt_text),coalesce(_identifiable_children,false),auth.uid(),auth.uid())
    returning id into v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,new_data)
    values(auth.uid(),v_id,'fan_gallery','created',jsonb_build_object('image_path',_image_path,'photo_date',_photo_date,'identifiable_children',_identifiable_children));
  else
    select * into v_old from public.fan_gallery where id=_record_id for update;
    if not found then raise exception 'Fan photo not found'; end if;
    v_override:=v_admin and v_old.created_by<>auth.uid();
    if _image_path<>v_old.image_path and split_part(_image_path,'/',1)<>auth.uid()::text then raise exception 'Replacement uploads must be in your own folder'; end if;
    if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
    update public.fan_gallery set image_path=_image_path,caption=nullif(btrim(_caption),''),fixture_url=nullif(btrim(_fixture_url),''),
      photo_date=_photo_date,alt_text=btrim(_alt_text),identifiable_children=coalesce(_identifiable_children,false),
      consent_confirmed=false,child_consent_confirmed=false,status='draft',approved_by=null,approved_at=null,
      updated_by=auth.uid(),updated_at=now() where id=_record_id returning id into v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
    values(auth.uid(),v_id,'fan_gallery',case when v_override then 'admin_override_updated' else 'updated_reset_to_draft' end,
      nullif(btrim(_reason),''),v_override,to_jsonb(v_old),jsonb_build_object('image_path',_image_path,'caption',_caption,'fixture_url',_fixture_url,'photo_date',_photo_date,'alt_text',_alt_text,'identifiable_children',_identifiable_children));
  end if;
  return v_id;
end $function$;
revoke all on function public.media_save_fan_photo(uuid,text,text,text,date,text,boolean,text) from public, anon;
grant execute on function public.media_save_fan_photo(uuid,text,text,text,date,text,boolean,text) to authenticated;

create or replace function public.media_set_fan_photo_status(
  _record_id uuid,_approved boolean,_consent_confirmed boolean,_identifiable_children boolean,
  _child_consent_confirmed boolean,_reason text
) returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.fan_gallery%rowtype; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  select * into v_old from public.fan_gallery where id=_record_id for update;
  if not found then raise exception 'Fan photo not found'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  if _approved and not coalesce(_consent_confirmed,false) then raise exception 'Confirm that fans are aware or the photo was taken in a public matchday setting'; end if;
  if _approved and coalesce(_identifiable_children,false) and not coalesce(_child_consent_confirmed,false) then raise exception 'Approval blocked: identifiable children require consent confirmation'; end if;
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.fan_gallery set status=case when _approved then 'approved' else 'draft' end,
    consent_confirmed=coalesce(_consent_confirmed,false),identifiable_children=coalesce(_identifiable_children,false),
    child_consent_confirmed=coalesce(_child_consent_confirmed,false),
    approved_by=case when _approved then auth.uid() else null end,approved_at=case when _approved then now() else null end,
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'fan_gallery',case when _approved then 'approved' else 'unapproved' end,
    nullif(btrim(_reason),''),v_override,jsonb_build_object('status',v_old.status,'consent_confirmed',v_old.consent_confirmed,'identifiable_children',v_old.identifiable_children,'child_consent_confirmed',v_old.child_consent_confirmed),
    jsonb_build_object('status',case when _approved then 'approved' else 'draft' end,'consent_confirmed',_consent_confirmed,'identifiable_children',_identifiable_children,'child_consent_confirmed',_child_consent_confirmed));
  return true;
end $function$;
revoke all on function public.media_set_fan_photo_status(uuid,boolean,boolean,boolean,boolean,text) from public, anon;
grant execute on function public.media_set_fan_photo_status(uuid,boolean,boolean,boolean,boolean,text) to authenticated;

create or replace function public.media_reorder_fan_photos(_ids uuid[],_reason text)
returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_id uuid; v_idx integer; v_old integer;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if coalesce(array_length(_ids,1),0)=0
     or array_length(_ids,1)<>(select count(*) from public.fan_gallery)
     or (select count(distinct x) from unnest(_ids) x)<>array_length(_ids,1) then
    raise exception 'Photo order must include every gallery photo exactly once';
  end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  if v_admin and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Administrator override reason required'; end if;
  for v_id,v_idx in select x.id,(x.ordinality-1)::integer from unnest(_ids) with ordinality as x(id,ordinality) loop
    select order_index into v_old from public.fan_gallery where id=v_id for update;
    if not found then raise exception 'Photo order contains an unknown record'; end if;
    update public.fan_gallery set order_index=v_idx,updated_by=auth.uid(),updated_at=now() where id=v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
    values(auth.uid(),v_id,'fan_gallery','reordered',nullif(btrim(_reason),''),v_admin,
      jsonb_build_object('order_index',v_old),jsonb_build_object('order_index',v_idx));
  end loop;
  return true;
end $function$;
revoke all on function public.media_reorder_fan_photos(uuid[],text) from public, anon;
grant execute on function public.media_reorder_fan_photos(uuid[],text) to authenticated;

create or replace function public.media_remove_fan_photo(_record_id uuid,_reason text)
returns text language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.fan_gallery%rowtype; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  select * into v_old from public.fan_gallery where id=_record_id for update;
  if not found then raise exception 'Fan photo not found'; end if;
  v_admin:=private.is_active_platform_admin(auth.uid());
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Administrator override reason required'; end if;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data)
  values(auth.uid(),_record_id,'fan_gallery','removed',nullif(btrim(_reason),''),v_override,to_jsonb(v_old));
  delete from public.fan_gallery where id=_record_id;
  return v_old.image_path;
end $function$;
revoke all on function public.media_remove_fan_photo(uuid,text) from public, anon;
grant execute on function public.media_remove_fan_photo(uuid,text) to authenticated;

commit;

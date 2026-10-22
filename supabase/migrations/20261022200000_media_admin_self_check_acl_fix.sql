-- Fix Media Team upload failures caused by nested platform-admin helper ACLs.
-- Expose only a self-check, never an arbitrary-user admin lookup.
begin;

create or replace function public.media_is_current_user_platform_admin()
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select auth.uid() is not null
     and private.is_active_platform_admin(auth.uid())
$function$;
revoke all on function public.media_is_current_user_platform_admin() from public, anon;
grant execute on function public.media_is_current_user_platform_admin() to authenticated;

create or replace function public.media_can_manage()
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select auth.uid() is not null and (
    public.media_is_current_user_platform_admin()
    or 'media_team' = any(private.current_club_roles())
  )
$function$;
revoke all on function public.media_can_manage() from public, anon;
grant execute on function public.media_can_manage() to authenticated;

-- Recreate the workspace/RPC entry points with the safe self-admin predicate.
create or replace function public.media_get_workspace()
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
begin
  if auth.uid() is null or not public.media_can_manage() then
    raise exception 'Media Team or Platform Admin access required';
  end if;
  return jsonb_build_object(
    'is_platform_admin',public.media_is_current_user_platform_admin(),
    'roles',to_jsonb(private.current_club_roles()),
    'posts',coalesce((select jsonb_agg(to_jsonb(p) order by p.planned_for nulls last,p.updated_at desc) from public.social_posts p),'[]'::jsonb),
    'photos',coalesce((select jsonb_agg(to_jsonb(g) order by g.order_index,g.photo_date desc,g.created_at desc) from public.fan_gallery g),'[]'::jsonb)
  );
end $function$;
revoke all on function public.media_get_workspace() from public, anon;
grant execute on function public.media_get_workspace() to authenticated;

-- All Media RPCs evaluate the current actor only; no arbitrary-user admin
-- checks are needed in these functions.
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
  v_admin:=public.media_is_current_user_platform_admin();
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
      planned_for=_planned_for,posted_at=null,post_url=nullif(btrim(_post_url),''),status=_status,
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
  v_admin:=public.media_is_current_user_platform_admin();
  if not v_admin and v_old.created_by<>auth.uid() then raise exception 'Media Team members may approve their own social posts'; end if;
  if _new_status='approved' and v_old.status not in ('drafted','approved') then raise exception 'Save the post as drafted before approval'; end if;
  if _new_status='posted' and v_old.status<>'approved' then raise exception 'Approve the post before marking it posted'; end if;
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.social_posts set status=_new_status,
    approved_by=case when _new_status in ('approved','posted') then coalesce(approved_by,auth.uid()) else null end,
    approved_at=case when _new_status in ('approved','posted') then coalesce(approved_at,now()) else null end,
    posted_at=case when _new_status='posted' then coalesce(posted_at,current_date) else null end,
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'social_post','status_'||_new_status,nullif(btrim(_reason),''),v_override,
    jsonb_build_object('status',v_old.status),jsonb_build_object('status',_new_status,'approved_by',case when _new_status in ('approved','posted') then auth.uid() else null end,'posted_at',case when _new_status='posted' then coalesce(v_old.posted_at,current_date) else null end));
  return true;
end $function$;
revoke all on function public.media_set_social_status(uuid,text,text) from public, anon;
grant execute on function public.media_set_social_status(uuid,text,text) to authenticated;

create or replace function public.media_save_social_stats(
  _record_id uuid,_reach bigint,_impressions bigint,_likes bigint,_comments bigint,
  _shares bigint,_saves bigint,_link_clicks bigint,_followers_gained bigint,_posted_at date,_post_url text,_reason text
) returns boolean language plpgsql security definer set search_path=''
as $function$
declare v_admin boolean; v_old public.social_posts%rowtype; v_override boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  if least(_reach,_impressions,_likes,_comments,_shares,_saves,_link_clicks,_followers_gained)<0 then raise exception 'Stats cannot be negative'; end if;
  select * into v_old from public.social_posts where id=_record_id for update;
  if not found then raise exception 'Social post not found'; end if;
  v_admin:=public.media_is_current_user_platform_admin();
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.social_posts set reach=_reach,impressions=_impressions,likes=_likes,comments=_comments,shares=_shares,
    saves=_saves,link_clicks=_link_clicks,followers_gained=_followers_gained,posted_at=case when status='posted' then coalesce(_posted_at,posted_at) else posted_at end,post_url=nullif(btrim(_post_url),''),
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'social_post','stats_updated',nullif(btrim(_reason),''),v_override,
    jsonb_build_object('reach',v_old.reach,'impressions',v_old.impressions,'likes',v_old.likes,'comments',v_old.comments,'shares',v_old.shares,'saves',v_old.saves,'link_clicks',v_old.link_clicks,'followers_gained',v_old.followers_gained,'posted_at',v_old.posted_at,'post_url',v_old.post_url),
    jsonb_build_object('reach',_reach,'impressions',_impressions,'likes',_likes,'comments',_comments,'shares',_shares,'saves',_saves,'link_clicks',_link_clicks,'followers_gained',_followers_gained,'posted_at',case when v_old.status='posted' then coalesce(_posted_at,v_old.posted_at) else v_old.posted_at end,'post_url',_post_url));
  return true;
end $function$;
revoke all on function public.media_save_social_stats(uuid,bigint,bigint,bigint,bigint,bigint,bigint,bigint,bigint,date,text,text) from public, anon;
grant execute on function public.media_save_social_stats(uuid,bigint,bigint,bigint,bigint,bigint,bigint,bigint,bigint,date,text,text) to authenticated;

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
  v_admin:=public.media_is_current_user_platform_admin();
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
    if v_old.identifiable_children and not coalesce(_identifiable_children,false) then
      if not v_admin then raise exception 'Only Platform Admin may clear an identifiable-children flag'; end if;
      if length(btrim(coalesce(_reason,'')))<3 then raise exception 'Reason required to clear identifiable-children flag'; end if;
      v_override:=true;
    end if;
    if _image_path<>v_old.image_path and split_part(_image_path,'/',1)<>auth.uid()::text then raise exception 'Replacement uploads must be in your own folder'; end if;
    if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
    update public.fan_gallery set image_path=_image_path,caption=nullif(btrim(_caption),''),fixture_url=nullif(btrim(_fixture_url),''),photo_date=_photo_date,
      alt_text=btrim(_alt_text),identifiable_children=coalesce(_identifiable_children,false),consent_confirmed=false,child_consent_confirmed=false,
      status='draft',approved_by=null,approved_at=null,updated_by=auth.uid(),updated_at=now()
    where id=_record_id returning id into v_id;
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
declare v_admin boolean; v_old public.fan_gallery%rowtype; v_override boolean; v_children boolean;
begin
  if auth.uid() is null or not public.media_can_manage() then raise exception 'Media Team access required'; end if;
  select * into v_old from public.fan_gallery where id=_record_id for update;
  if not found then raise exception 'Fan photo not found'; end if;
  v_admin:=public.media_is_current_user_platform_admin();
  v_children:=v_old.identifiable_children or coalesce(_identifiable_children,false);
  if _approved and not coalesce(_consent_confirmed,false) then raise exception 'Confirm that fans are aware or the photo was taken in a public matchday setting'; end if;
  if _approved and v_children and not coalesce(_child_consent_confirmed,false) then raise exception 'Approval blocked: identifiable children require consent confirmation'; end if;
  v_override:=v_admin and v_old.created_by<>auth.uid();
  if v_override and (length(btrim(coalesce(_reason,'')))<3 or length(_reason)>1000) then raise exception 'Administrator override reason (3–1000 characters) required'; end if;
  update public.fan_gallery set status=case when _approved then 'approved' else 'draft' end,
    consent_confirmed=coalesce(_consent_confirmed,false),identifiable_children=v_children,
    child_consent_confirmed=case when v_children then coalesce(_child_consent_confirmed,false) else false end,
    approved_by=case when _approved then auth.uid() else null end,approved_at=case when _approved then now() else null end,
    updated_by=auth.uid(),updated_at=now() where id=_record_id;
  insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
  values(auth.uid(),_record_id,'fan_gallery',case when _approved then 'approved' else 'unapproved' end,
    nullif(btrim(_reason),''),v_override,jsonb_build_object('status',v_old.status,'consent_confirmed',v_old.consent_confirmed,'identifiable_children',v_old.identifiable_children,'child_consent_confirmed',v_old.child_consent_confirmed),
    jsonb_build_object('status',case when _approved then 'approved' else 'draft' end,'consent_confirmed',_consent_confirmed,'identifiable_children',v_children,'child_consent_confirmed',case when v_children then _child_consent_confirmed else false end));
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
  if coalesce(array_length(_ids,1),0)=0 or array_length(_ids,1)<>(select count(*) from public.fan_gallery)
     or (select count(distinct x) from unnest(_ids) x)<>array_length(_ids,1) then raise exception 'Photo order must include every gallery photo exactly once'; end if;
  v_admin:=public.media_is_current_user_platform_admin();
  if v_admin and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Administrator override reason required'; end if;
  for v_id,v_idx in select x.id,(x.ordinality-1)::integer from unnest(_ids) with ordinality as x(id,ordinality) loop
    select order_index into v_old from public.fan_gallery where id=v_id for update;
    if not found then raise exception 'Photo order contains an unknown record'; end if;
    update public.fan_gallery set order_index=v_idx,updated_by=auth.uid(),updated_at=now() where id=v_id;
    insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
    values(auth.uid(),v_id,'fan_gallery','reordered',nullif(btrim(_reason),''),v_admin,jsonb_build_object('order_index',v_old),jsonb_build_object('order_index',v_idx));
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
  v_admin:=public.media_is_current_user_platform_admin();
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

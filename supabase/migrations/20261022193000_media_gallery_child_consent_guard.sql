-- Harden child-consent enforcement for an already-installed media migration.
begin;

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
    if v_old.identifiable_children and not coalesce(_identifiable_children,false) then
      if not v_admin then raise exception 'Only Platform Admin may clear an identifiable-children flag'; end if;
      if length(btrim(coalesce(_reason,'')))<3 then raise exception 'Reason required to clear identifiable-children flag'; end if;
      v_override:=true;
    end if;
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
  v_admin:=private.is_active_platform_admin(auth.uid());
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

commit;

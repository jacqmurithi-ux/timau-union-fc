begin;

alter table public.homepage_hero_slides
  drop constraint if exists homepage_hero_slides_link_url_check;
alter table public.homepage_hero_slides
  add constraint homepage_hero_slides_link_url_check
  check (
    link_url is null or (
      length(link_url) <= 2000
      and link_url !~ '[[:cntrl:]]'
      and position(chr(92) in link_url) = 0
      and link_url ~* '^(https?://|/[^/])'
    )
  );

create or replace function public.homepage_hero_save(
  _slide_id uuid, _image_path text, _caption text, _link_url text,
  _alt_text text, _ends_at timestamptz, _order_index integer
) returns uuid language plpgsql security definer set search_path=''
as $$
declare
  v_id uuid;
  v_old public.homepage_hero_slides%rowtype;
  v_count integer;
  v_action text;
begin
  if auth.uid() is null or not public.homepage_hero_can_manage() then
    raise exception 'Admin or Media Team access required';
  end if;
  if length(btrim(coalesce(_caption,''))) not between 1 and 180 then
    raise exception 'Caption must be 1–180 characters';
  end if;
  if length(btrim(coalesce(_alt_text,''))) not between 5 and 300 then
    raise exception 'Descriptive alt text is required';
  end if;
  if _image_path is null or length(_image_path)>1000 then
    raise exception 'Invalid image path';
  end if;
  if _link_url is not null and (
    length(_link_url)>2000
    or _link_url ~ '[[:cntrl:]]'
    or position(chr(92) in _link_url)>0
    or _link_url !~* '^(https?://|/[^/])'
  ) then
    raise exception 'Link must be a safe HTTP(S) URL or internal path';
  end if;
  if _order_index not between 0 and 2 then
    raise exception 'Slide order must be between 1 and 3';
  end if;
  if _ends_at is not null and _ends_at <= now() then
    raise exception 'End date must be in the future';
  end if;

  perform pg_advisory_xact_lock(hashtext('homepage_hero_slides_max_three'));
  if _slide_id is null then
    select count(*) into v_count
      from public.homepage_hero_slides
      where ends_at is null or ends_at > now();
    if v_count >= 3 then
      raise exception 'Maximum of 3 active homepage hero slides';
    end if;
    if _image_path !~ ('^'||auth.uid()::text||'/[A-Za-z0-9._-]+$') then
      raise exception 'New images must be uploaded to your own folder';
    end if;
    if not exists (
      select 1 from storage.objects o
      where o.bucket_id='homepage-hero' and o.name=_image_path
    ) then
      raise exception 'Uploaded image not found in homepage hero storage';
    end if;
    insert into public.homepage_hero_slides
      (image_path,caption,link_url,alt_text,ends_at,order_index,created_by,updated_by)
    values
      (_image_path,btrim(_caption),nullif(btrim(_link_url),''),btrim(_alt_text),_ends_at,_order_index,auth.uid(),auth.uid())
    returning id into v_id;
    insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key)
      values(auth.uid(),v_id,btrim(_caption),'created');
  else
    select * into v_old from public.homepage_hero_slides where id=_slide_id for update;
    if not found then raise exception 'Slide not found'; end if;
    if v_old.image_path <> _image_path then
      if _image_path !~ ('^'||auth.uid()::text||'/[A-Za-z0-9._-]+$') then
        raise exception 'Replacement image must be uploaded to your own folder';
      end if;
      if not exists (
        select 1 from storage.objects o
        where o.bucket_id='homepage-hero' and o.name=_image_path
      ) then
        raise exception 'Replacement image not found in homepage hero storage';
      end if;
      insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key)
        values(auth.uid(),_slide_id,v_old.caption,'image_replaced');
    end if;
    v_action := case
      when v_old.image_path = _image_path
       and v_old.caption = btrim(_caption)
       and v_old.link_url is not distinct from nullif(btrim(_link_url),'')
       and v_old.alt_text = btrim(_alt_text)
       and v_old.ends_at is not distinct from _ends_at
       and v_old.order_index is distinct from _order_index
      then 'reordered'
      else 'updated'
    end;
    update public.homepage_hero_slides
      set image_path=_image_path,caption=btrim(_caption),
          link_url=nullif(btrim(_link_url),''),alt_text=btrim(_alt_text),
          ends_at=_ends_at,order_index=_order_index,
          updated_by=auth.uid(),updated_at=now()
      where id=_slide_id returning id into v_id;
    insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key)
      values(auth.uid(),v_id,btrim(_caption),v_action);
  end if;
  return v_id;
end
$$;
revoke all on function public.homepage_hero_save(uuid,text,text,text,text,timestamptz,integer) from public, anon;
grant execute on function public.homepage_hero_save(uuid,text,text,text,text,timestamptz,integer) to authenticated;

commit;

-- Homepage hero slides: public reads only active rows; writes go through guarded RPCs.
begin;

create table if not exists public.homepage_hero_slides (
  id uuid primary key default gen_random_uuid(),
  image_path text not null unique check (length(image_path) between 1 and 1000),
  caption text not null check (length(btrim(caption)) between 1 and 180),
  link_url text check (link_url is null or (length(link_url) <= 2000 and link_url ~* '^https?://|^/')),
  alt_text text not null check (length(btrim(alt_text)) between 5 and 300),
  order_index integer not null default 0 check (order_index between 0 and 2),
  ends_at timestamptz,
  created_by uuid not null references auth.users(id),
  updated_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists homepage_hero_active_order_idx
  on public.homepage_hero_slides(order_index, created_at)
  where ends_at is null or ends_at > now();

alter table public.homepage_hero_slides enable row level security;
revoke all on public.homepage_hero_slides from public, anon, authenticated;
grant select (id, caption, link_url, alt_text, order_index, ends_at, image_path)
  on public.homepage_hero_slides to anon, authenticated;

create policy homepage_hero_public_active_read on public.homepage_hero_slides
  for select to anon, authenticated
  using (ends_at is null or ends_at > now());

create table if not exists private.homepage_hero_audit (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  slide_id uuid,
  caption text not null,
  action_key text not null check (action_key in ('created','updated','removed','expired','image_replaced','reordered')),
  created_at timestamptz not null default now()
);
alter table private.homepage_hero_audit enable row level security;
revoke all on private.homepage_hero_audit from public, anon, authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('homepage-hero','homepage-hero',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=10485760,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create or replace function public.homepage_hero_can_manage()
returns boolean language sql stable security definer set search_path=''
as $$
  select auth.uid() is not null and (
    private.is_active_platform_admin(auth.uid())
    or 'media_team' = any(private.current_club_roles())
  )
$$;
revoke all on function public.homepage_hero_can_manage() from public, anon;
grant execute on function public.homepage_hero_can_manage() to authenticated;

create policy homepage_hero_storage_public_read on storage.objects
 for select to anon, authenticated using (bucket_id = 'homepage-hero' and exists (select 1 from public.homepage_hero_slides s where s.image_path = storage.objects.name and (s.ends_at is null or s.ends_at > now())));
create policy homepage_hero_storage_manager_insert on storage.objects
 for insert to authenticated with check (bucket_id = 'homepage-hero' and public.homepage_hero_can_manage());
create policy homepage_hero_storage_manager_update on storage.objects
 for update to authenticated using (bucket_id = 'homepage-hero' and public.homepage_hero_can_manage())
 with check (bucket_id = 'homepage-hero' and public.homepage_hero_can_manage());
create policy homepage_hero_storage_manager_delete on storage.objects
 for delete to authenticated using (bucket_id = 'homepage-hero' and public.homepage_hero_can_manage());

create or replace function public.homepage_hero_save(
  _slide_id uuid, _image_path text, _caption text, _link_url text, _alt_text text, _ends_at timestamptz, _order_index integer
) returns uuid language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_old public.homepage_hero_slides%rowtype; v_count integer;
begin
  if auth.uid() is null or not public.homepage_hero_can_manage() then raise exception 'Admin or Media Team access required'; end if;
  if length(btrim(coalesce(_caption,''))) not between 1 and 180 then raise exception 'Caption must be 1–180 characters'; end if;
  if length(btrim(coalesce(_alt_text,''))) not between 5 and 300 then raise exception 'Descriptive alt text is required'; end if;
  if _image_path is null or length(_image_path)>1000 or _image_path !~ ('^'||auth.uid()::text||'/[A-Za-z0-9._-]+$') then raise exception 'Invalid image path'; end if;
  if _link_url is not null and (length(_link_url)>2000 or _link_url !~* '^(https?://|/)') then raise exception 'Link must be an HTTP(S) URL or internal path'; end if;
  if _order_index not between 0 and 2 then raise exception 'Slide order must be between 1 and 3'; end if;
  if _ends_at is not null and _ends_at <= now() then raise exception 'End date must be in the future'; end if;
  if _slide_id is null then
    select count(*) into v_count from public.homepage_hero_slides where ends_at is null or ends_at>now();
    if v_count >= 3 then raise exception 'Maximum of 3 active homepage hero slides'; end if;
    insert into public.homepage_hero_slides(image_path,caption,link_url,alt_text,ends_at,order_index,created_by,updated_by)
    values(_image_path,btrim(_caption),nullif(btrim(_link_url),''),btrim(_alt_text),_ends_at,_order_index,auth.uid(),auth.uid()) returning id into v_id;
    insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key) values(auth.uid(),v_id,btrim(_caption),'created');
  else
    select * into v_old from public.homepage_hero_slides where id=_slide_id for update;
    if not found then raise exception 'Slide not found'; end if;
    if v_old.image_path <> _image_path then
      insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key) values(auth.uid(),_slide_id,v_old.caption,'image_replaced');
    end if;
    update public.homepage_hero_slides set image_path=_image_path,caption=btrim(_caption),link_url=nullif(btrim(_link_url),''),alt_text=btrim(_alt_text),ends_at=_ends_at,order_index=_order_index,updated_by=auth.uid(),updated_at=now()
      where id=_slide_id returning id into v_id;
    insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key) values(auth.uid(),v_id,btrim(_caption),'updated');
  end if;
  return v_id;
end
$$;
revoke all on function public.homepage_hero_save(uuid,text,text,text,text,timestamptz,integer) from public, anon;
grant execute on function public.homepage_hero_save(uuid,text,text,text,text,timestamptz,integer) to authenticated;

create or replace function public.homepage_hero_remove(_slide_id uuid)
returns text language plpgsql security definer set search_path=''
as $$
declare v public.homepage_hero_slides%rowtype;
begin
  if auth.uid() is null or not public.homepage_hero_can_manage() then raise exception 'Admin or Media Team access required'; end if;
  select * into v from public.homepage_hero_slides where id=_slide_id for update;
  if not found then raise exception 'Slide not found'; end if;
  -- Return the path so the client removes the object via Supabase Storage API before/after RPC.
  insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key) values(auth.uid(),v.id,v.caption,'removed');
  delete from public.homepage_hero_slides where id=_slide_id;
  return v.image_path;
end
$$;
revoke all on function public.homepage_hero_remove(uuid) from public, anon;
grant execute on function public.homepage_hero_remove(uuid) to authenticated;

create or replace function public.homepage_hero_expired_paths()
returns table(slide_id uuid, image_path text, caption text)
language plpgsql security definer set search_path=''
as $$
begin
  if not public.homepage_hero_can_manage() then raise exception 'Admin or Media Team access required'; end if;
  return query select s.id,s.image_path,s.caption from public.homepage_hero_slides s where s.ends_at is not null and s.ends_at <= now() order by s.ends_at;
end
$$;
revoke all on function public.homepage_hero_expired_paths() from public, anon;
grant execute on function public.homepage_hero_expired_paths() to authenticated;

commit;

-- Service-role-only hard delete used by the scheduled cleanup function.
create or replace function public.homepage_hero_expire(_slide_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$
declare v public.homepage_hero_slides%rowtype;
begin
  if coalesce(current_setting('request.jwt.claim.role', true),'') <> 'service_role' then raise exception 'Service role required'; end if;
  select * into v from public.homepage_hero_slides where id=_slide_id and ends_at is not null and ends_at<=now() for update;
  if not found then return false; end if;
  insert into private.homepage_hero_audit(actor_user_id,slide_id,caption,action_key) values(v.updated_by,v.id,v.caption,'expired');
  delete from public.homepage_hero_slides where id=v.id;
  return true;
end
$$;
revoke all on function public.homepage_hero_expire(uuid) from public, anon, authenticated;
grant execute on function public.homepage_hero_expire(uuid) to service_role;

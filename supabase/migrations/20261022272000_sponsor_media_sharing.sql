-- Sponsor media sharing controls and storage access limited to linked, tagged sponsor records.
begin;

create or replace function public.media_get_share_options(_table text,_record_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; v_old jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r) or 'media_team'=any(r)) then raise exception 'Media Team, Chairman or admin required' using errcode='42501'; end if;
 if _table not in ('social_posts','fan_gallery') then raise exception 'Unsupported media type'; end if;
 if _table='social_posts' then
   select to_jsonb(p) into v_old from public.social_posts p where p.id=_record_id;
 else
   select to_jsonb(p) into v_old from public.fan_gallery p where p.id=_record_id;
 end if;
 if v_old is null then raise exception 'Media record not found'; end if;
 if not admin and not ('chairman'=any(r) or 'media_team'=any(r) or (v_old->>'created_by')::uuid=auth.uid()) then raise exception 'Media Team or authorised club lead required' using errcode='42501'; end if;
 return jsonb_build_object(
  'sponsors',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'name',c.data->>'name') order by c.data->>'name')
    from private.club_records c where c.record_type='sponsor' and c.publication_status='approved'),'[]'::jsonb),
  'selected',coalesce((select jsonb_agg(sh.sponsor_record_id) from private.sponsor_media_shares sh where sh.media_table=_table and sh.media_record_id=_record_id),'[]'::jsonb)
 );
end $$;
revoke all on function public.media_get_share_options(text,uuid) from public, anon;
grant execute on function public.media_get_share_options(text,uuid) to authenticated;

create or replace function public.media_set_sponsor_shares(_table text,_record_id uuid,_sponsor_record_ids uuid[],_reason text default null)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare r text[]; admin boolean; v_old jsonb; v_new jsonb; v_ids uuid[]:=coalesce(_sponsor_record_ids,'{}'::uuid[]); v_before uuid[];
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 r:=private.current_club_roles(); admin:=private.is_active_platform_admin(auth.uid());
 if not (admin or 'chairman'=any(r) or 'media_team'=any(r)) then raise exception 'Media Team, Chairman or admin required' using errcode='42501'; end if;
 if admin and length(btrim(coalesce(_reason,'')))<3 then raise exception 'Admin override reason required'; end if;
 if _table='social_posts' then
   select to_jsonb(p) into v_old from public.social_posts p where p.id=_record_id for update;
 elsif _table='fan_gallery' then
   select to_jsonb(p) into v_old from public.fan_gallery p where p.id=_record_id for update;
 else raise exception 'Unsupported media record type'; end if;
 if v_old is null then raise exception 'Media record not found'; end if;
 if not admin and not ('chairman'=any(r) or 'media_team'=any(r) or (v_old->>'created_by')::uuid=auth.uid()) then raise exception 'Media Team or authorised club lead required' using errcode='42501'; end if;
 if exists(select 1 from unnest(v_ids) x where not exists(select 1 from private.club_records c where c.id=x and c.record_type='sponsor' and c.publication_status='approved')) then raise exception 'Every shared sponsor must be an approved sponsor record'; end if;
 select coalesce(array_agg(sh.sponsor_record_id order by sh.sponsor_record_id),'{}'::uuid[]) into v_before from private.sponsor_media_shares sh where sh.media_table=_table and sh.media_record_id=_record_id;
 v_old:=v_old||jsonb_build_object('share_with_sponsor_ids',v_before);
 delete from private.sponsor_media_shares where media_table=_table and media_record_id=_record_id;
 insert into private.sponsor_media_shares(media_table,media_record_id,sponsor_record_id,shared_by)
 select _table,_record_id,x,auth.uid() from unnest(v_ids) x;
 v_new:=jsonb_build_object('share_with_sponsor_ids',v_ids);
 insert into private.media_record_audit(actor_user_id,record_id,record_type,action_key,reason,is_admin_override,old_data,new_data)
 values(auth.uid(),_record_id,case when _table='social_posts' then 'social_post' else 'fan_gallery' end,'sponsor_share_changed',nullif(btrim(_reason),''),admin,v_old,v_new);
 return jsonb_build_object('ok',true,'share_with_sponsor_ids',to_jsonb(v_ids));
end $$;
revoke all on function public.media_set_sponsor_shares(text,uuid,uuid[],text) from public, anon;
grant execute on function public.media_set_sponsor_shares(text,uuid,uuid[],text) to authenticated;

create or replace function private.sponsor_can_read_agreement_path(_name text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from private.sponsor_user_links l join private.sponsor_agreements a on a.sponsor_record_id=l.sponsor_record_id where l.user_id=auth.uid() and l.active and a.signed_document_path=_name) $$;
create or replace function private.sponsor_can_read_tagged_media_path(_name text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from private.sponsor_user_links l join private.sponsor_media_shares sh on sh.sponsor_record_id=l.sponsor_record_id and sh.media_table='fan_gallery' join public.fan_gallery g on g.id=sh.media_record_id and g.image_path=_name and g.status='approved' where l.user_id=auth.uid() and l.active) $$;
revoke all on function private.sponsor_can_read_agreement_path(text) from public, anon;
revoke all on function private.sponsor_can_read_tagged_media_path(text) from public, anon;
grant execute on function private.sponsor_can_read_agreement_path(text) to authenticated;
grant execute on function private.sponsor_can_read_tagged_media_path(text) to authenticated;

do $$
begin
 if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sponsor_can_read_tagged_agreements') then
  create policy sponsor_can_read_tagged_agreements on storage.objects for select to authenticated
  using (bucket_id='sponsor-agreements' and private.sponsor_can_read_agreement_path(name));
 end if;
 if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='sponsor_can_read_tagged_media') then
  create policy sponsor_can_read_tagged_media on storage.objects for select to authenticated
  using (bucket_id='fans-gallery' and private.sponsor_can_read_tagged_media_path(name));
 end if;
end $$;
commit;
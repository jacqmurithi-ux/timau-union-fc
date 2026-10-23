-- Optional poster images for published club news. Public reads; Media Team-only writes.
begin;
alter table public.club_news add column if not exists poster_path text;
alter table public.club_news drop constraint if exists club_news_poster_path_length;
alter table public.club_news add constraint club_news_poster_path_length check (poster_path is null or length(poster_path) <= 500);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('club-news-posters','club-news-posters',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists club_news_posters_media_upload on storage.objects;
create policy club_news_posters_media_upload on storage.objects for insert to authenticated with check (bucket_id='club-news-posters' and public.club_news_can_manage() and split_part(name,'/',1)=auth.uid()::text);
drop policy if exists club_news_posters_media_update on storage.objects;
create policy club_news_posters_media_update on storage.objects for update to authenticated using (bucket_id='club-news-posters' and public.club_news_can_manage() and split_part(name,'/',1)=auth.uid()::text) with check (bucket_id='club-news-posters' and public.club_news_can_manage() and split_part(name,'/',1)=auth.uid()::text);
drop policy if exists club_news_posters_media_delete on storage.objects;
create policy club_news_posters_media_delete on storage.objects for delete to authenticated using (bucket_id='club-news-posters' and public.club_news_can_manage() and split_part(name,'/',1)=auth.uid()::text);
drop function if exists public.club_news_save(uuid,text,text,boolean);
create function public.club_news_save(_id uuid,_title text,_body text,_publish boolean,_poster_path text default null)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v_id uuid; v_status text; begin
 if not public.club_news_can_manage() then raise exception 'Media Team access required' using errcode='42501'; end if;
 if length(btrim(coalesce(_title,''))) not between 3 and 180 or length(btrim(coalesce(_body,''))) not between 3 and 5000 then raise exception 'Title must be 3–180 characters and news body 3–5000 characters'; end if;
 if _poster_path is not null and (length(_poster_path)>500 or split_part(_poster_path,'/',1)<>auth.uid()::text or _poster_path !~* '\\.(jpg|jpeg|png|webp)$') then raise exception 'Poster path is invalid'; end if;
 perform pg_advisory_xact_lock(hashtext('club_news_published_limit'));
 if _publish and (select count(*) from public.club_news where status='published' and id is distinct from _id)>=3 then raise exception 'Three news items are already published. Delete or unpublish an older item first.'; end if;
 v_status:=case when _publish then 'published' else 'draft' end;
 if _id is null then insert into public.club_news(title,body,status,published_at,poster_path,created_by,updated_by) values(btrim(_title),btrim(_body),v_status,case when _publish then now() end,_poster_path,auth.uid(),auth.uid()) returning id into v_id;
 else update public.club_news set title=btrim(_title),body=btrim(_body),status=v_status,published_at=case when _publish then coalesce(published_at,now()) end,poster_path=case when _poster_path is not null then _poster_path else poster_path end,updated_by=auth.uid(),updated_at=now() where id=_id returning id into v_id; if v_id is null then raise exception 'News item not found'; end if; end if;
 return v_id;
end $$;
revoke all on function public.club_news_save(uuid,text,text,boolean,text) from public,anon;
grant execute on function public.club_news_save(uuid,text,text,boolean,text) to authenticated;
create or replace function public.club_news_manage_list()
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin if not public.club_news_can_manage() then raise exception 'Media Team access required' using errcode='42501'; end if; return coalesce((select jsonb_agg(to_jsonb(n) order by n.updated_at desc) from public.club_news n),'[]'::jsonb); end $$;
revoke all on function public.club_news_manage_list() from public,anon;
grant execute on function public.club_news_manage_list() to authenticated;
create or replace function public.club_news_public_list()
returns jsonb language sql stable security invoker set search_path=''
as $$ select coalesce((select jsonb_agg(to_jsonb(n) order by n.published_at desc,n.created_at desc) from (select id,title,body,poster_path,published_at,created_at from public.club_news where status='published' order by published_at desc,created_at desc limit 3) n),'[]'::jsonb) $$;
revoke all on function public.club_news_public_list() from public;
grant execute on function public.club_news_public_list() to anon,authenticated;
commit;
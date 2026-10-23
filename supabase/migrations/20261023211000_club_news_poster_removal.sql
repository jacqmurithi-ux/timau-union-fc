-- Allow an editor to explicitly remove a news poster while preserving it on ordinary edits.
drop function if exists public.club_news_save(uuid,text,text,boolean,text);
create function public.club_news_save(_id uuid,_title text,_body text,_publish boolean,_poster_path text default null,_remove_poster boolean default false)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v_id uuid; v_status text; begin
 if not public.club_news_can_manage() then raise exception 'Media Team access required' using errcode='42501'; end if;
 if length(btrim(coalesce(_title,''))) not between 3 and 180 or length(btrim(coalesce(_body,''))) not between 3 and 5000 then raise exception 'Title must be 3–180 characters and news body 3–5000 characters'; end if;
 if _poster_path is not null and (length(_poster_path)>500 or split_part(_poster_path,'/',1)<>auth.uid()::text or _poster_path !~* '\\.(jpg|jpeg|png|webp)$') then raise exception 'Poster path is invalid'; end if;
 perform pg_advisory_xact_lock(hashtext('club_news_published_limit'));
 if _publish and (select count(*) from public.club_news where status='published' and id is distinct from _id)>=3 then raise exception 'Three news items are already published. Delete or unpublish an older item first.'; end if;
 v_status:=case when _publish then 'published' else 'draft' end;
 if _id is null then insert into public.club_news(title,body,status,published_at,poster_path,created_by,updated_by) values(btrim(_title),btrim(_body),v_status,case when _publish then now() end,_poster_path,auth.uid(),auth.uid()) returning id into v_id;
 else update public.club_news set title=btrim(_title),body=btrim(_body),status=v_status,published_at=case when _publish then coalesce(published_at,now()) end,poster_path=case when _remove_poster then null when _poster_path is not null then _poster_path else poster_path end,updated_by=auth.uid(),updated_at=now() where id=_id returning id into v_id; if v_id is null then raise exception 'News item not found'; end if; end if;
 return v_id;
end $$;
revoke all on function public.club_news_save(uuid,text,text,boolean,text,boolean) from public,anon;
grant execute on function public.club_news_save(uuid,text,text,boolean,text,boolean) to authenticated;
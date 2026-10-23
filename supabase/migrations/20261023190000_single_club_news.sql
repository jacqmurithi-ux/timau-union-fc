-- Single public news workflow. Only Media Team and active platform admins may manage news.
begin;
create table if not exists public.club_news (
 id uuid primary key default gen_random_uuid(),
 title text not null check (length(btrim(title)) between 3 and 180),
 body text not null check (length(btrim(body)) between 3 and 5000),
 status text not null default 'draft' check (status in ('draft','published')),
 published_at timestamptz,
 created_by uuid not null references auth.users(id),
 updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check ((status='published' and published_at is not null) or (status='draft' and published_at is null))
);
create index if not exists club_news_published_order_idx on public.club_news(status,published_at desc);
alter table public.club_news enable row level security;
revoke all on public.club_news from public, anon, authenticated;
create policy club_news_public_read on public.club_news for select to anon,authenticated using(status='published');
grant select(id,title,body,status,published_at,created_at,updated_at) on public.club_news to anon,authenticated;
create or replace function public.club_news_can_manage()
returns boolean language sql stable security definer set search_path=''
as $$ select auth.uid() is not null and (private.is_active_platform_admin(auth.uid()) or private.current_club_roles() && array['media_team']::text[]) $$;
revoke all on function public.club_news_can_manage() from public,anon;
grant execute on function public.club_news_can_manage() to authenticated;
create or replace function public.club_news_public_list()
returns jsonb language sql stable security definer set search_path=''
as $$ select coalesce((select jsonb_agg(to_jsonb(n) order by n.published_at desc,n.created_at desc) from (select id,title,body,published_at,created_at from public.club_news where status='published' order by published_at desc,created_at desc limit 3) n),'[]'::jsonb) $$;
revoke all on function public.club_news_public_list() from public;
grant execute on function public.club_news_public_list() to anon,authenticated;
create or replace function public.club_news_manage_list()
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin if not public.club_news_can_manage() then raise exception 'Secretary or Media Team access required' using errcode='42501'; end if; return coalesce((select jsonb_agg(to_jsonb(n) order by n.updated_at desc) from public.club_news n),'[]'::jsonb); end $$;
revoke all on function public.club_news_manage_list() from public,anon;
grant execute on function public.club_news_manage_list() to authenticated;
create or replace function public.club_news_save(_id uuid,_title text,_body text,_publish boolean)
returns uuid language plpgsql security definer set search_path=''
as $$ declare v_id uuid; v_status text; begin
 if not public.club_news_can_manage() then raise exception 'Secretary or Media Team access required' using errcode='42501'; end if;
 if length(btrim(coalesce(_title,''))) not between 3 and 180 or length(btrim(coalesce(_body,''))) not between 3 and 5000 then raise exception 'Title must be 3–180 characters and news body 3–5000 characters'; end if;
 perform pg_advisory_xact_lock(hashtext('club_news_published_limit'));
 if _publish and (select count(*) from public.club_news where status='published' and id is distinct from _id)>=3 then raise exception 'Three news items are already published. Delete or unpublish an older item first.'; end if;
 v_status:=case when _publish then 'published' else 'draft' end;
 if _id is null then insert into public.club_news(title,body,status,published_at,created_by,updated_by) values(btrim(_title),btrim(_body),v_status,case when _publish then now() end,auth.uid(),auth.uid()) returning id into v_id;
 else update public.club_news set title=btrim(_title),body=btrim(_body),status=v_status,published_at=case when _publish then coalesce(published_at,now()) end,updated_by=auth.uid(),updated_at=now() where id=_id returning id into v_id; if v_id is null then raise exception 'News item not found'; end if; end if; return v_id;
end $$;
revoke all on function public.club_news_save(uuid,text,text,boolean) from public,anon;
grant execute on function public.club_news_save(uuid,text,text,boolean) to authenticated;
create or replace function public.club_news_delete(_id uuid)
returns boolean language plpgsql security definer set search_path=''
as $$ begin if not public.club_news_can_manage() then raise exception 'Secretary or Media Team access required' using errcode='42501'; end if; delete from public.club_news where id=_id; return found; end $$;
revoke all on function public.club_news_delete(uuid) from public,anon;
grant execute on function public.club_news_delete(uuid) to authenticated;
commit;
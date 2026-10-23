-- Harden public news reads and remove Secretary news-management access.
create or replace function public.club_news_can_manage()
returns boolean
language sql stable security definer set search_path=''
as $$ select auth.uid() is not null and (private.is_active_platform_admin(auth.uid()) or private.current_club_roles() && array['media_team']::text[]) $$;
revoke all on function public.club_news_can_manage() from public,anon;
grant execute on function public.club_news_can_manage() to authenticated;

create or replace function public.club_news_public_list()
returns jsonb
language sql stable security invoker set search_path=''
as $$ select coalesce((select jsonb_agg(to_jsonb(n) order by n.published_at desc,n.created_at desc) from (select id,title,body,published_at,created_at from public.club_news where status='published' order by published_at desc,created_at desc limit 3) n),'[]'::jsonb) $$;
revoke all on function public.club_news_public_list() from public;
grant execute on function public.club_news_public_list() to anon,authenticated;
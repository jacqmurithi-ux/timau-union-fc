-- Replace SECURITY DEFINER views with authenticated, role-checked RPCs.
-- The functions return only sponsor-safe fields and aggregate-only club summaries.
begin;

drop view if exists public.social_sponsor_posts;
drop view if exists public.social_monthly_summary;

create or replace function public.social_sponsor_posts()
returns table (
  id uuid,
  title text,
  channel text,
  planned_for date,
  posted_at date,
  post_url text,
  post_type text,
  views bigint,
  reach bigint,
  likes bigint,
  comments bigint,
  shares bigint,
  saves bigint,
  link_clicks bigint,
  captured_on date
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.title, p.channel, p.planned_for, p.posted_at, p.post_url, p.post_type,
         coalesce(s.views, 0)::bigint, coalesce(s.reach, 0)::bigint,
         coalesce(s.likes, 0)::bigint, coalesce(s.comments, 0)::bigint,
         coalesce(s.shares, 0)::bigint, coalesce(s.saves, 0)::bigint,
         coalesce(s.link_clicks, 0)::bigint, s.captured_on
  from public.social_posts p
  left join public.social_post_stats s on s.post_id = p.id
  where auth.uid() is not null
    and 'sponsor' = any(private.current_club_roles())
    and p.sponsor_id = private.current_sponsor_record_id()
    and p.status = 'posted'
  order by p.posted_at desc nulls last, p.planned_for desc nulls last;
$$;

create or replace function public.social_monthly_summary()
returns table (
  month date,
  platform text,
  posts_published bigint,
  sponsor_tagged_posts bigint,
  total_views bigint,
  average_views bigint,
  likes bigint,
  comments bigint,
  shares bigint,
  engagement_rate numeric,
  followers_gained bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with post_month as (
    select date_trunc('month', coalesce(p.posted_at, p.planned_for))::date as month,
           p.channel as platform,
           count(*)::bigint as posts_published,
           count(*) filter (where p.sponsor_id is not null)::bigint as sponsor_tagged_posts,
           coalesce(sum(s.views), 0)::bigint as total_views,
           coalesce(round(avg(s.views)), 0)::bigint as average_views,
           coalesce(sum(s.likes), 0)::bigint as likes,
           coalesce(sum(s.comments), 0)::bigint as comments,
           coalesce(sum(s.shares), 0)::bigint as shares,
           case when coalesce(sum(s.views), 0) = 0 then 0::numeric
                else round(sum(s.likes + s.comments + s.shares)::numeric / sum(s.views)::numeric, 4)
           end as engagement_rate
    from public.social_posts p
    left join public.social_post_stats s on s.post_id = p.id
    where p.status = 'posted'
      and coalesce(p.posted_at, p.planned_for) is not null
    group by 1, 2
  ), follower_month as (
    select f.month, f.platform, sum(f.new_followers)::bigint as followers_gained
    from public.social_followers f
    group by f.month, f.platform
  )
  select coalesce(pm.month, fm.month),
         coalesce(pm.platform, fm.platform),
         coalesce(pm.posts_published, 0)::bigint,
         coalesce(pm.sponsor_tagged_posts, 0)::bigint,
         coalesce(pm.total_views, 0)::bigint,
         coalesce(pm.average_views, 0)::bigint,
         coalesce(pm.likes, 0)::bigint,
         coalesce(pm.comments, 0)::bigint,
         coalesce(pm.shares, 0)::bigint,
         coalesce(pm.engagement_rate, 0)::numeric,
         coalesce(fm.followers_gained, 0)::bigint
  from post_month pm
  full join follower_month fm using (month, platform)
  where auth.uid() is not null
    and (
      private.current_club_roles() && array[
        'media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach','sponsor'
      ]::text[]
      or exists (
        select 1 from private.platform_admins pa
        where pa.user_id = (select auth.uid()) and pa.active
      )
    );
$$;

revoke all on function public.social_sponsor_posts() from public, anon, authenticated;
grant execute on function public.social_sponsor_posts() to authenticated;
revoke all on function public.social_monthly_summary() from public, anon, authenticated;
grant execute on function public.social_monthly_summary() to authenticated;

commit;

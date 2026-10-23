-- Fix social statistics authorization without granting direct access to private.platform_admins.
-- Use the existing SECURITY DEFINER admin-check helper from policies and the monthly summary RPC.
begin;

drop policy if exists social_posts_stats_internal_read on public.social_posts;
create policy social_posts_stats_internal_read on public.social_posts
for select to authenticated
using (
  private.current_club_roles() && array[
    'media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach'
  ]::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_posts_stats_internal_insert on public.social_posts;
create policy social_posts_stats_internal_insert on public.social_posts
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_posts_stats_internal_update on public.social_posts;
create policy social_posts_stats_internal_update on public.social_posts
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_post_stats_insert on public.social_post_stats;
create policy social_post_stats_insert on public.social_post_stats
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_post_stats_update on public.social_post_stats;
create policy social_post_stats_update on public.social_post_stats
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_followers_read on public.social_followers;
create policy social_followers_read on public.social_followers
for select to authenticated
using (
  private.current_club_roles() && array[
    'media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach'
  ]::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_followers_insert on public.social_followers;
create policy social_followers_insert on public.social_followers
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

drop policy if exists social_followers_update on public.social_followers;
create policy social_followers_update on public.social_followers
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or private.is_active_platform_admin((select auth.uid()))
);

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
      or private.is_active_platform_admin((select auth.uid()))
    );
$$;

revoke all on function public.social_monthly_summary() from public, anon, authenticated;
grant execute on function public.social_monthly_summary() to authenticated;

commit;

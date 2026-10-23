-- Social media performance tracking; additive to the existing Media Team publishing calendar.
begin;

alter table public.social_posts
  add column if not exists post_type text not null default 'other',
  add column if not exists sponsor_id uuid references private.club_records(id) on delete set null,
  add column if not exists fixture_id uuid references private.club_records(id) on delete set null;

alter table public.social_posts drop constraint if exists social_posts_channel_check;
alter table public.social_posts add constraint social_posts_channel_check
  check (channel = any (array['Facebook','Instagram','TikTok','X','YouTube','WhatsApp channel','WhatsApp Channel','Other']::text[]));
alter table public.social_posts drop constraint if exists social_posts_post_type_check;
alter table public.social_posts add constraint social_posts_post_type_check
  check (post_type = any (array['match day','result','fixture','player','sponsor','training','community','other']::text[]));

create table if not exists public.social_post_stats (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null unique references public.social_posts(id) on delete cascade,
  views bigint not null default 0 check (views >= 0),
  reach bigint not null default 0 check (reach >= 0),
  likes bigint not null default 0 check (likes >= 0),
  comments bigint not null default 0 check (comments >= 0),
  shares bigint not null default 0 check (shares >= 0),
  saves bigint not null default 0 check (saves >= 0),
  link_clicks bigint not null default 0 check (link_clicks >= 0),
  captured_on date not null default current_date,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table if not exists public.social_followers (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform = any (array['Facebook','Instagram','TikTok','X','YouTube','WhatsApp channel','WhatsApp Channel','Other']::text[])),
  month date not null check (extract(day from month) = 1),
  followers_count bigint not null default 0 check (followers_count >= 0),
  new_followers bigint not null default 0 check (new_followers >= 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  unique(platform, month)
);

create index if not exists social_posts_posted_at_idx on public.social_posts(posted_at);
create index if not exists social_posts_sponsor_id_idx on public.social_posts(sponsor_id) where sponsor_id is not null;
create index if not exists social_posts_channel_posted_at_idx on public.social_posts(channel, posted_at);
create index if not exists social_post_stats_captured_on_idx on public.social_post_stats(captured_on);

alter table public.social_post_stats enable row level security;
revoke all on public.social_post_stats, public.social_followers from public, anon;
revoke all on public.social_posts from public, anon;

create or replace function public.social_stats_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $
begin
  new.updated_at = now();
  return new;
end;
$;
revoke all on function public.social_stats_touch_updated_at() from public, anon, authenticated;
drop trigger if exists social_post_stats_touch_updated_at on public.social_post_stats;
create trigger social_post_stats_touch_updated_at before update on public.social_post_stats for each row execute function public.social_stats_touch_updated_at();
drop trigger if exists social_followers_touch_updated_at on public.social_followers;
create trigger social_followers_touch_updated_at before update on public.social_followers for each row execute function public.social_stats_touch_updated_at();
alter table public.social_followers enable row level security;

drop policy if exists social_posts_stats_internal_read on public.social_posts;
create policy social_posts_stats_internal_read on public.social_posts
for select to authenticated
using (
  private.current_club_roles() && array['media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
  
);

drop policy if exists social_posts_stats_internal_insert on public.social_posts;
create policy social_posts_stats_internal_insert on public.social_posts
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
);

drop policy if exists social_posts_stats_internal_update on public.social_posts;
create policy social_posts_stats_internal_update on public.social_posts
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
);

drop policy if exists social_post_stats_read on public.social_post_stats;
create policy social_post_stats_read on public.social_post_stats
for select to authenticated
using (exists (
  select 1 from public.social_posts p where p.id = post_id
));
drop policy if exists social_post_stats_write on public.social_post_stats;
create policy social_post_stats_write on public.social_post_stats
for all to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
);

drop policy if exists social_followers_read on public.social_followers;
create policy social_followers_read on public.social_followers
for select to authenticated
using (
  private.current_club_roles() && array['media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
   );
drop policy if exists social_followers_write on public.social_followers;
create policy social_followers_write on public.social_followers
for all to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()))
);

grant select, insert, update on public.social_posts to authenticated;
grant select, insert, update on public.social_post_stats to authenticated;
grant select, insert, update on public.social_followers to authenticated;

-- Sponsor-safe projection: sponsors never receive direct SELECT access to social_posts.
create or replace view public.social_sponsor_posts as
select p.id, p.title, p.channel, p.planned_for, p.posted_at, p.post_url, p.post_type,
       s.views, s.reach, s.likes, s.comments, s.shares, s.saves, s.link_clicks, s.captured_on
from public.social_posts p
left join public.social_post_stats s on s.post_id = p.id
where p.sponsor_id = private.current_sponsor_record_id()
  and 'sponsor' = any(private.current_club_roles());

alter view public.social_sponsor_posts set (security_invoker = false);
revoke all on public.social_sponsor_posts from public, anon;
grant select on public.social_sponsor_posts to authenticated;

create or replace view public.social_monthly_summary as
with post_month as (
  select date_trunc('month', coalesce(p.posted_at, p.planned_for))::date as month,
         p.channel as platform, count(*)::bigint as posts_published,
         count(*) filter (where p.sponsor_id is not null)::bigint as sponsor_tagged_posts,
         coalesce(sum(s.views),0)::bigint as total_views,
         coalesce(round(avg(s.views)),0)::bigint as average_views,
         coalesce(sum(s.likes),0)::bigint as likes,
         coalesce(sum(s.comments),0)::bigint as comments,
         coalesce(sum(s.shares),0)::bigint as shares,
         case when coalesce(sum(s.views),0)=0 then 0::numeric
              else round((sum(s.likes+s.comments+s.shares)::numeric / sum(s.views)::numeric),4) end as engagement_rate
  from public.social_posts p
  left join public.social_post_stats s on s.post_id=p.id
  where p.status='posted' and coalesce(p.posted_at,p.planned_for) is not null
  group by 1,2
), follower_month as (
  select month, platform, sum(new_followers)::bigint as followers_gained
  from public.social_followers group by month,platform
)
select coalesce(pm.month,fm.month) as month,
       coalesce(pm.platform,fm.platform) as platform,
       coalesce(pm.posts_published,0)::bigint as posts_published,
       coalesce(pm.sponsor_tagged_posts,0)::bigint as sponsor_tagged_posts,
       coalesce(pm.total_views,0)::bigint as total_views,
       coalesce(pm.average_views,0)::bigint as average_views,
       coalesce(pm.likes,0)::bigint as likes,
       coalesce(pm.comments,0)::bigint as comments,
       coalesce(pm.shares,0)::bigint as shares,
       coalesce(pm.engagement_rate,0)::numeric as engagement_rate,
       coalesce(fm.followers_gained,0)::bigint as followers_gained
from post_month pm full join follower_month fm using(month,platform)
where private.current_club_roles() && array['media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach','sponsor']::text[]
   or exists (select 1 from private.platform_admins pa where pa.user_id = (select auth.uid()));

-- This view deliberately exposes aggregate-only club-wide monthly totals to signed-in users,
-- including sponsors; it does not expose post titles, URLs, or sponsor identities.
alter view public.social_monthly_summary set (security_invoker = false);
revoke all on public.social_monthly_summary from public, anon;
grant select on public.social_monthly_summary to authenticated;

commit;
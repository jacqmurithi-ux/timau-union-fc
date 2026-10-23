-- Honor the active flag for platform administrators in social-statistics RLS.
begin;

drop policy if exists social_posts_stats_internal_read on public.social_posts;
create policy social_posts_stats_internal_read on public.social_posts
for select to authenticated
using (
  private.current_club_roles() && array[
    'media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach'
  ]::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_posts_stats_internal_insert on public.social_posts;
create policy social_posts_stats_internal_insert on public.social_posts
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_posts_stats_internal_update on public.social_posts;
create policy social_posts_stats_internal_update on public.social_posts
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_post_stats_insert on public.social_post_stats;
create policy social_post_stats_insert on public.social_post_stats
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_post_stats_update on public.social_post_stats;
create policy social_post_stats_update on public.social_post_stats
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_followers_read on public.social_followers;
create policy social_followers_read on public.social_followers
for select to authenticated
using (
  private.current_club_roles() && array[
    'media_team','chairman','secretary','treasurer','sponsor_lead','team_manager','coach'
  ]::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_followers_insert on public.social_followers;
create policy social_followers_insert on public.social_followers
for insert to authenticated
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

drop policy if exists social_followers_update on public.social_followers;
create policy social_followers_update on public.social_followers
for update to authenticated
using (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
)
with check (
  private.current_club_roles() && array['media_team','chairman']::text[]
  or exists (
    select 1 from private.platform_admins pa
    where pa.user_id = (select auth.uid()) and pa.active
  )
);

commit;

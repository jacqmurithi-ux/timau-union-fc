-- Ensure social-statistics records cannot be deleted through the client API.
begin;
revoke delete on public.social_posts, public.social_post_stats, public.social_followers
  from public, anon, authenticated;
commit;

-- Only authenticated callers may invoke sponsor-safe stats RPCs.
begin;
revoke all on function public.social_sponsor_posts() from public, anon, authenticated;
grant execute on function public.social_sponsor_posts() to authenticated;
commit;

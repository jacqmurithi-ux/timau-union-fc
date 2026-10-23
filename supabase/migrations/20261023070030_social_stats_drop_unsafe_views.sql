-- Remove legacy SECURITY DEFINER views.
-- The UI now uses role-checked RPCs; leaving these views exposed can bypass underlying RLS.
begin;
revoke all on table public.social_sponsor_posts, public.social_monthly_summary from public, anon, authenticated;
drop view if exists public.social_sponsor_posts;
drop view if exists public.social_monthly_summary;
commit;

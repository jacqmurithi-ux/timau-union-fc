-- Remove privileged views; sponsor-safe reporting is provided by guarded RPCs.
begin;
drop view if exists public.social_sponsor_posts;
drop view if exists public.social_monthly_summary;
commit;

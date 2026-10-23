-- Social Stats are editable, not deletable, by authenticated users.
-- RLS remains the row-level authorization boundary; this removes unnecessary table-level DELETE grants.
begin;
revoke delete on table public.social_post_stats, public.social_followers from public, anon, authenticated;
commit;

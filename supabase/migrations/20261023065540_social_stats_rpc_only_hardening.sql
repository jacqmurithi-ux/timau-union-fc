-- Keep social reporting on the caller-checked SECURITY DEFINER RPCs, not views.
-- The RPCs return only aggregate club metrics or the current sponsor's published posts.
drop view if exists public.social_sponsor_posts;
drop view if exists public.social_monthly_summary;
revoke execute on function private.current_sponsor_record_id() from authenticated;

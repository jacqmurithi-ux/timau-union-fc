-- Ensure the club Admin role can record and override home attendance.
-- Sponsor accounts remain excluded from raw attendance access.
begin;
drop policy if exists "attendance internal readers" on public.match_attendance;
create policy "attendance internal readers" on public.match_attendance
for select to authenticated
using (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman','treasurer','sponsor_lead','media_team','coach']::text[]
);
drop policy if exists "attendance authorized writers" on public.match_attendance;
create policy "attendance authorized writers" on public.match_attendance
for insert to authenticated
with check (
  recorded_by = auth.uid()
  and (
    private.is_active_platform_admin(auth.uid())
    or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
  )
);
drop policy if exists "attendance authorized editors" on public.match_attendance;
create policy "attendance authorized editors" on public.match_attendance
for update to authenticated
using (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
)
with check (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','team_manager','chairman','vice_chairman']::text[]
);
commit;

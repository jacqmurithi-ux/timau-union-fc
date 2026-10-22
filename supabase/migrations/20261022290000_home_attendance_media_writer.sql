-- Allow the Secretary, club Admin and Media Team to record attendance without a separate approval step.
-- Preserve existing operational writer roles and keep sponsor/reader roles read-only.
begin;
drop policy if exists "attendance authorized writers" on public.match_attendance;
create policy "attendance authorized writers" on public.match_attendance
for insert to authenticated
with check (
  recorded_by = auth.uid()
  and (
    private.is_active_platform_admin(auth.uid())
    or private.current_club_roles() && array['admin','secretary','media_team','team_manager','chairman','vice_chairman']::text[]
  )
);
drop policy if exists "attendance authorized editors" on public.match_attendance;
create policy "attendance authorized editors" on public.match_attendance
for update to authenticated
using (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','media_team','team_manager','chairman','vice_chairman']::text[]
)
with check (
  private.is_active_platform_admin(auth.uid())
  or private.current_club_roles() && array['admin','secretary','media_team','team_manager','chairman','vice_chairman']::text[]
);
commit;

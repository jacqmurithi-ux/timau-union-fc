# Team Manager workspace — test checklist

Run on **Union Test** first. Apply `supabase/environment-adapters/union-test-team-manager-role-adapter.sql`, then `supabase/migrations/20261021130000_team_manager_workspace.sql`. For production, use `supabase/environment-adapters/production-team-manager-role-adapter.sql` before the migration. Do not apply either directly to production before Union Test checks pass.

- [ ] Sign in as a Team Manager. Workspace shows Players, Fixtures & results, Activities, Import FKF roster, and the eight TM duty sections. News and Sponsors tabs are absent.
- [ ] As TM, call `club_save_record` for `news` and `sponsor`; both must fail. Try the same through the UI.
- [ ] Create a TM-owned player/fixture/activity record. Another non-admin role cannot edit it or change its publication status. TM can edit TM-owned records.
- [ ] As TM, try editing a player/fixture/activity record created by a different role; database function must reject it.
- [ ] As a non-TM role, attempt `tm_save_record`; it must fail. The welfare role can view only `discipline_welfare` records and cannot edit them.
- [ ] Create/edit a TM duty record. It saves as `draft`; edits reset approval. No duty record becomes public by default.
- [ ] Submit a transport plan with fare-per-player information and a Treasurer submission note. Verify the TM UI does not provide a money-approval action.
- [ ] As Chairman or active Platform Admin, edit a TM duty record and supply an override reason. Confirm `private.tm_record_audit` stores actor, timestamp, record ID, old/new JSON, old/new status, override flag, and reason.
- [ ] As Chairman or active Platform Admin, change publication status with a reason; confirm an audit row is written.
- [ ] As Player Welfare, verify welfare notes are visible, while squad, transport, and other TM sections are not returned.
- [ ] Verify Media Team and Sponsor Lead retain their existing News/Sponsors permissions when they do not also have the Team Manager role.
- [ ] Run existing workspace and public-site smoke tests; verify unapproved content remains private.

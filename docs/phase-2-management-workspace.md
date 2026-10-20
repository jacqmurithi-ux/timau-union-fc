# Phase 2 — Private operational workspace
**Isolated draft branch. The project status record reports application to Union Test on 2026-10-20; this document update does not independently verify the live database. Production and GitHub Pages are intended to remain unchanged.**

## Workspace
Private `/app/workspace.html`: player register, fixtures/results, news, sponsors and activities. All writes use protected RPCs. New records are drafts; editing resets approval. Publication approval follows the record-level permission map enforced by the database. Chairman and Secretary can approve any supported record type; Team Manager and Coach can approve players, fixtures/results and activities; Media Team can approve news; Sponsor Lead can approve sponsor records. Treasurer, Vice Chairman, Player and Supporter have no publication approval by default. An active Platform Admin retains system-wide override authority. Every decision requires a reason. Public RPC returns approved records only and allowlists public fields. Public website remains unchanged pending separate integration review.

## Live schema reconciliation
Production `owvvimydkjsjlrmnzvdi`: `private.account_access` keyed by `user_id`; `private.role_assignments` keyed directly by `user_id` with `active`; profile/admin/audit tables in `private`.
Union Test `dzpquzfghapjodmrmavw`: `public.club_memberships` keyed by membership ID; `public.role_assignments` joins via `membership_id` and uses `revoked_at`; it also has invitation and rate-limit tables not observed in Production. Role keys match but identity joins differ.
The shared RPC contract uses environment-specific mutually exclusive adapters in `supabase/environment-adapters/`. Production migration listing returned no records despite existing access tables, so Production migration history is unverified.

## Role boundaries
Chairman/Secretary: create/edit and approve all supported record types. Team Manager/Coach: create/edit and approve players, fixtures/results and activities. Media Team: create/edit and approve news. Sponsor Lead: create/edit and approve sponsor records. Treasurer/Vice Chairman have no operational record type by default unless explicitly granted in the permission map. Platform Admin retains system-wide override authority, independent of club role.

## Release gates
1. Union Test adapter `phase_2_union_test_role_adapter` and core migration `phase_2_workspace_core` applied successfully through Supabase migration tooling.
2. Read-only catalog/grant checks passed: both tables exist with RLS enabled; direct table access and internal helper execution are revoked; only the intended RPCs are granted.
3. Smoke tests passed for a confirmed Media Team role: workspace bundle returns only that role and no records; a valid news draft save succeeded inside a transaction that was rolled back; public anonymous read returned an empty list.
4. Negative tests were rejected as expected: Media Team could not save a sponsor, could not approve publication, and authenticated direct table SELECT returned permission denied.
5. Post-migration security advisor rerun completed. Review warnings below; RLS-no-policy findings are intentional defense-in-depth for private-schema tables with no direct grants. The public approved-content RPC is intentionally callable by anon and is `SECURITY DEFINER` because source rows live in the private schema; confirm this exception and its allowlist before release.
6. Remaining tests before release: Chairman/Secretary approval happy path; Team Manager/Coach scope; pending/revoked/unconfirmed identities; unknown record IDs; malformed JSON and oversized values; direct table writes; inspect function owners/search paths; verify actual HTTP/PostgREST calls and re-run advisors after final fixes.
7. Production migration approval and public deployment approval remain separate required gates.
No fixtures, players, scores, sponsors or contacts were added; test save was rolled back and both workspace tables remain empty. Public placeholders remain until integration is reviewed.


## Baseline security-advisor observations (before Phase 2 changes)
- Production's current advisor reported private-schema tables with RLS but no policies (consistent with the existing private-schema / revoked-direct-access model; confirm grants remain revoked) and five SECURITY DEFINER public access RPCs executable by authenticated users but not anon. These RPCs need internal Platform Admin/identity checks; this branch does not change them.
- Production also reported leaked-password protection disabled. This is an existing Auth configuration warning, not a Phase 2 migration result.
- Union Test's post-migration advisor reports RLS enabled with no policies for the two private tables (intentional, but documented as an INFO finding); one anon-executable SECURITY DEFINER public-content RPC (intentional but must remain narrowly allowlisted); four authenticated-executable SECURITY DEFINER workspace RPCs (intended, protected by internal identity/role checks); and leaked-password protection disabled (existing Auth configuration warning).
- Production remains unchanged; its leaked-password protection warning remains outstanding. Review SECURITY DEFINER owners and paths before any release, and decide whether to document/suppress expected advisor warnings or redesign the public RPC.


## Follow-up review — 2026-10-20
- Corrected the manual core rollback to drop `private.valid_club_record_data(text,jsonb)` before removing the workspace tables, and added a warning that rollback is destructive and does not remove the environment-specific `private.current_club_roles()` adapter.
- The previously recorded Union Test catalog and Media Team smoke-test results are historical status claims. They are not a substitute for the remaining authenticated role/identity tests listed above.
- **Release remains blocked** until the remaining checks below are executed against Union Test with controlled test identities and their actual results are recorded. Do not run these against Production.


## Approval authority clarification
- The Phase 2 core migration now permits publication decisions for users whose active club role is authorized for that record type, using `private.role_can_manage_record(...)`; the existing protected `private.is_active_platform_admin(auth.uid())` check grants Platform Admin a system-wide override.
- The workspace bundle identifies active Platform Admin sessions and allows them to view/manage all workspace record types, even if they have no separate club role. It returns a per-record `can_approve` value so the interface shows approval controls only where the user's role permits them. The database RPC independently enforces the same role/type boundary.
- This change is code on the isolated draft branch only. It has not been applied to Union Test or Production and must be tested with an active Platform Admin, a Chairman/Secretary who is not a Platform Admin, and a pending/revoked user before release.

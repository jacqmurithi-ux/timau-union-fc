# Phase 2 — Private operational workspace
**Isolated draft branch. Applied to Union Test only on 2026-10-20; Production and GitHub Pages unchanged.**

## Workspace
Private `/app/workspace.html`: player register, fixtures/results, news, sponsors and activities. All writes use protected RPCs. New records are drafts; editing resets approval. Chairman and Secretary can approve, return to draft or archive with a reason. Public RPC returns approved records only and allowlists public fields. Public website remains unchanged pending separate integration review.

## Live schema reconciliation
Production `owvvimydkjsjlrmnzvdi`: `private.account_access` keyed by `user_id`; `private.role_assignments` keyed directly by `user_id` with `active`; profile/admin/audit tables in `private`.
Union Test `dzpquzfghapjodmrmavw`: `public.club_memberships` keyed by membership ID; `public.role_assignments` joins via `membership_id` and uses `revoked_at`; it also has invitation and rate-limit tables not observed in Production. Role keys match but identity joins differ.
The shared RPC contract uses environment-specific mutually exclusive adapters in `supabase/environment-adapters/`. Production migration listing returned no records despite existing access tables, so Production migration history is unverified.

## Role boundaries
Chairman/Secretary: all record types and publication approval. Team Manager/Coach: players, fixtures and activities. Media Team: news. Sponsor Lead: sponsors. Treasurer/Vice Chairman have no operational record type by default. Platform Admin stays separate and does not automatically gain club record permissions.

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

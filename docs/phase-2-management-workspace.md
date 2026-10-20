# Phase 2 — Private operational workspace
**Isolated draft only. No Supabase schema change or public deployment has been made.**

## Workspace
Private `/app/workspace.html`: player register, fixtures/results, news, sponsors and activities. All writes use protected RPCs. New records are drafts; editing resets approval. Chairman and Secretary can approve, return to draft or archive with a reason. Public RPC returns approved records only and allowlists public fields. Public website remains unchanged pending separate integration review.

## Live schema reconciliation
Production `owvvimydkjsjlrmnzvdi`: `private.account_access` keyed by `user_id`; `private.role_assignments` keyed directly by `user_id` with `active`; profile/admin/audit tables in `private`.
Union Test `dzpquzfghapjodmrmavw`: `public.club_memberships` keyed by membership ID; `public.role_assignments` joins via `membership_id` and uses `revoked_at`; it also has invitation and rate-limit tables not observed in Production. Role keys match but identity joins differ.
The shared RPC contract uses environment-specific mutually exclusive adapters in `supabase/environment-adapters/`. Production migration listing returned no records despite existing access tables, so Production migration history is unverified.

## Role boundaries
Chairman/Secretary: all record types and publication approval. Team Manager/Coach: players, fixtures and activities. Media Team: news. Sponsor Lead: sponsors. Treasurer/Vice Chairman have no operational record type by default. Platform Admin stays separate and does not automatically gain club record permissions.

## Release gates
1. Review both adapters, core migration and rollback.
2. Apply only the Union Test adapter and reviewed core schema to Union Test after explicit approval.
3. Run `supabase/tests/phase_2_workspace_contract.sql` for catalog/grant checks.
4. Use JWT-backed accounts for positive/negative tests: every role, pending/revoked users, guessed record IDs, direct table access, unauthorised approvals, public filtering.
5. Run Supabase security advisors and verify grants, SECURITY DEFINER owners/search paths, and no unintended row changes.
6. Obtain explicit Production migration approval and separate deployment approval before merging to main.
No fixtures, players, scores, sponsors or contacts have been invented. Public placeholders remain until integration is reviewed.

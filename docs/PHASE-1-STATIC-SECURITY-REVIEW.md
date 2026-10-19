# Phase 1 — Static Security Review (Repository-Only)

**Status:** Findings from source review only.  
**Review date:** 2026-10-19  
**Reviewed files:** `supabase/review-drafts/identity_roles_review_draft.sql`, `tests/PHASE-1-RLS-REVIEW-CHECKLIST.md`, and `docs/ROLE-PERMISSION-MATRIX.md`.  
**Target Supabase project:** `owvvimydkjsjlrmnzvdi` (`https://owvvimydkjsjlrmnzvdi.supabase.co`) — confirmed by the project owner on 2026-10-19 as the main Timau Union FC project.  
**Database access:** Not available during this review. The target project's schema, grants, function owners, Data API exposure settings, and existing data have **not** been inspected. A prior project reference (`dzpquzfghapjodmrmavw`) was incorrect for this work and must not be used for Timau Union FC.
**Execution status:** No SQL was run and no Supabase project was changed. This document does not approve the draft for execution.

## Summary

The draft is appropriately labelled review-only and intentionally omits client-side write policies. It is not yet ready for application. Resolve the items below, then review and test against a disposable non-production project before preparing any production migration.

## Findings

### F1 — Membership status and self-read policies are inconsistent with the release checklist

**Priority:** High  
**Evidence:** The SELECT policies on `public.user_profiles`, `public.club_memberships`, and `public.role_assignments` permit self-reads based on `auth.uid()` / membership ownership without requiring the membership to be active. A suspended or revoked user can therefore still read their own rows while their access token remains valid.

**Why it matters:** The checklist requires a suspended/revoked identity to be denied on protected requests, including requests from an existing session. The current policy behavior may be intentional for a status page, but that exception is not documented and conflicts with the stated release gate.

**Required decision:** Decide whether suspended/revoked users may read a minimal status response. If not, require active membership for these reads. If yes, expose only a narrow status path and explicitly test/document that exception. In either case, every business-data policy must independently require current authorization; hiding the UI is not sufficient.

### F2 — The schema does not enforce a single active Chairman

**Priority:** High  
**Evidence:** The partial unique index on `role_assignments` prevents one membership from having duplicate active assignments of the same role. It does not prevent two different memberships from simultaneously holding `chairman`.

**Why it matters:** `private.can_manage_club_roles()` grants role-management read authority to anyone with an active Chairman assignment. Multiple Chairmen would therefore multiply the number of users receiving that authority.

**Required change:** Confirm the club's intended rule, then enforce at most one active Chairman with a database-level invariant or a serialized trusted role-assignment operation. Add tests for concurrent assignment attempts and safe Chairman handover; do not rely only on application checks.

### F3 — SECURITY DEFINER execution context and private-schema state require verification

**Priority:** High  
**Evidence:** The two helper functions use `SECURITY DEFINER`, a fixed empty `search_path`, and fully qualified object references, which are good safeguards. However, the draft cannot prove the effective owner, owner privileges, existing schema state, or whether the `private` schema is excluded from the Data API.

**Why it matters:** These functions are used inside RLS policies and execute with their owner's privileges. If the owner cannot safely read the required tables, policy evaluation may fail or recurse; if ownership/privileges are broader than intended, the helper's security boundary may be weaker than expected.

**Required verification:** On a disposable test project, record the owner and privileges of each function, verify the schema is not exposed by the Data API, inspect grants on the schema and functions, and run positive/negative RLS tests. Do not infer these facts from this SQL file alone.

### F4 — Existing objects and grants are not fully covered by the draft

**Priority:** Medium–High  
**Evidence:** The draft uses `CREATE TABLE IF NOT EXISTS` and `CREATE SCHEMA IF NOT EXISTS`, then changes grants for named tables and named functions. If objects already exist with different definitions, these statements will not reconcile their structure. If the `private` schema already contains other functions, the draft does not review or reset their grants.

**Why it matters:** A successful run would not prove that existing objects match the intended schema or least-privilege model.

**Required change:** Preflight the target schema and migration history. Prefer a clean disposable test database for first validation. Explicitly inspect every existing object in `private`; only revoke/regrant privileges after confirming the impact on existing functions and dependencies. Do not use this draft as a blind repair migration.

### F5 — Role and membership lifecycle invariants are incomplete

**Priority:** Medium  
**Evidence:** The tables constrain status/role names, but do not enforce consistent combinations such as active membership with an activation timestamp, revoked membership with a revocation timestamp, or revoked role assignment with revocation metadata.

**Why it matters:** Trusted operations could accidentally produce contradictory state, making authorization and audit interpretation ambiguous.

**Required change:** Define the allowed state transitions and add appropriate CHECK constraints and/or trusted transactional operations. Test activation, suspension, revocation, restoration, role handover, and repeated requests. Ensure protected requests evaluate current database state rather than trusting stale client state.

### F6 — `updated_at` is not automatically maintained

**Priority:** Medium  
**Evidence:** `updated_at` defaults to `now()` on insert, but the draft does not define a trigger or trusted update operation that refreshes it.

**Why it matters:** Future backend updates could leave misleading timestamps.

**Required change:** Either add a reviewed update-timestamp trigger or have every trusted update operation set the field explicitly. Test the chosen behavior.

### F7 — Invitation acceptance and email binding remain unimplemented

**Priority:** High for the next implementation phase; not a defect in this intentionally limited schema alone  
**Evidence:** The draft has `invited_email` and `user_id`, but intentionally contains no trusted invitation/activation operation.

**Why it matters:** A table definition does not bind an invited email to a verified Auth identity. An invitee must never be able to choose or elevate their own role, and matching must use a verified identity and a trusted operation.

**Required gate:** Design the invitation lifecycle separately. Test mismatched email, expired/reused invite, existing account, revoked invitation, repeated acceptance, unauthorized actor, and role tampering. Keep all privileged credentials out of browser code.

### F8 — Audit payload and append-only behavior need a trusted write contract

**Priority:** Medium  
**Evidence:** The draft grants authenticated users SELECT on `audit_events` with a Chairman-only RLS policy and creates no client write policies, which is a good initial restriction. The table's `details` JSONB field has no content-level minimization rule, and trusted insert operations are not yet implemented.

**Why it matters:** Future server/database operations could accidentally store secrets or unnecessary personal information. The append-only property must be enforced by privileges and trusted write paths, not merely by the absence of client UI controls.

**Required gate:** Specify allowed audit fields, redact credentials/tokens, restrict who can write, and test that ordinary users cannot insert, update, or delete events and cannot read audit records outside their permission scope.

### F9 — Redundant role-assignment uniqueness rule

**Priority:** Low  
**Evidence:** The table-level unique constraint on `(membership_id, role_key, assigned_at)` is separate from the partial unique index on `(membership_id, role_key)` where `revoked_at IS NULL`. The former does not enforce the active-role rule and may be unnecessary unless it serves a documented historical purpose.

**Required change:** Confirm the intended historical semantics and remove redundant constraints/indexes in a reviewed revision if they do not serve a specific invariant.

## Required test matrix before execution

Run against a disposable non-production project with separate test identities for each role, an authenticated non-member, a suspended/revoked member, and anonymous access.

- Anonymous and non-member access to all private tables.
- Self-read behavior for active, suspended, and revoked memberships.
- Cross-member reads and direct REST calls with changed IDs.
- Chairman-only role governance and audit visibility.
- At most one active Chairman, including concurrent assignment attempts.
- Vice Chairman cannot assign, elevate, or revoke roles by default.
- No client INSERT/UPDATE/DELETE on membership, role, or audit tables.
- Helper function behavior for authenticated and unauthenticated callers.
- Existing private-schema objects and function grants are accounted for.
- Invitation binding and lifecycle tests before implementing that workflow.
- Verify RLS enabled on every exposed-schema table and verify private schema is not Data-API exposed.

Record the project reference, commit, SQL runner, test identity, request, expected result, actual result, and evidence. Never include secrets or tokens.

## Release decision

**Do not apply this draft to production.** The next safe step is to revise the draft and tests, then validate them on the disposable test project. The current Supabase connection could not inspect the target project, so none of the database-specific verification items above are marked passed.

# Phase 1 automated verification — 2026-10-19

Status: **Partial verification passed; release blocked.** All live database checks in this record targeted Union Test `dzpquzfghapjodmrmavw` only. Production `owvvimydkjsjlrmnzvdi` was not queried or modified. No Edge Function was deployed.

## Automated checks run in Union Test

Executed a read-only catalog verification plus a PL/pgSQL assertion block against the connected Union Test database.

- [x] Exactly the five expected identity/workflow tables were found with RLS enabled: `user_profiles`, `club_memberships`, `role_assignments`, `audit_events`, `invitation_requests`.
- [x] All nine `public.club_admin_*` privileged RPCs have `SECURITY DEFINER` and a fixed empty `search_path`.
- [x] All nine privileged RPCs deny EXECUTE to `anon` and `authenticated`, and allow EXECUTE to `service_role`.
- [x] No direct `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, or `TRIGGER` grants to `authenticated` on the five tables.
- [x] No direct `SELECT` grant to `anon` on the five tables.
- [x] Calling the invitation-begin RPC with a nonexistent/non-Chairman actor was rejected with insufficient privilege; no invitation was created.
- [x] Inspected the five SELECT policies: profile/membership/role visibility is self-scoped for active members or Chairman-authorized; invitation and audit reads are Chairman-authorized.
- [x] Confirmed schema-level SQL privileges show `anon` has no USAGE on `private`; `authenticated` has USAGE for policy helper calls. This does **not** prove the Supabase Data API Exposed schemas setting.
- [x] Supabase security advisor returned no findings.
- [x] Performance advisor currently reports six unused-index informational notices in this empty test project. These are not security findings and are not proof that indexes are unnecessary under production workload.

## What this verification does not prove

These are still release blockers and must not be marked passed based on catalog/SQL simulations:

- [ ] Dashboard confirmation that `private` is excluded from Data API Exposed schemas.
- [ ] Real HTTP/PostgREST requests using anonymous and separate authenticated test identities, including direct REST/RPC attempts.
- [ ] Real Auth Admin email delivery, correct redirect destination, unverified/mismatched email rejection, duplicate retry, provider failure, cancellation/expiry, and post-delivery database failure/reconciliation.
- [ ] Existing JWT/session behavior after suspension and revocation against protected resources.
- [ ] Verify configured `ALLOWED_ORIGINS` and `INVITE_REDIRECT_URL`, plus rate limiting/abuse controls.
- [ ] Independent review of the SQL and Edge Function, including the invitation delivery/checkpoint crash window and operational reconciliation runbook.
- [ ] Full test suite/lint/type checks executed in a controlled environment with output captured.
- [ ] Final reviewer approval before merge.

## Safe release posture

PR #7 remains a draft. The Edge Function remains undeployed. No production migration has been prepared for execution or applied. Continue only in Union Test until all release blockers are evidenced and independently reviewed.

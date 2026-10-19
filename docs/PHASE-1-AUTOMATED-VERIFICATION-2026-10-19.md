# Phase 1 automated verification — 2026-10-19

Status: **Partial verification passed; release blocked.** All live database checks in this record targeted Union Test `dzpquzfghapjodmrmavw` only. Production `owvvimydkjsjlrmnzvdi` was not queried or modified. No Edge Function was deployed.

## Automated checks run in Union Test

The repeatable SQL smoke-test is committed at [`tests/phase-1-union-test-catalog-assertions.sql`](../tests/phase-1-union-test-catalog-assertions.sql). It was executed against Union Test and completed without a raised exception. The database-backed rate-limit function was tested across all buckets: 5 invitation requests were allowed and request 6 denied; 10 activation attempts were allowed and attempt 11 denied; 60 admin mutations were allowed and mutation 61 denied. The temporary test counters were removed. Separate catalog queries inspected function grants and RLS policies.

- [x] Exactly the five expected identity/workflow tables were found with RLS enabled: `user_profiles`, `club_memberships`, `role_assignments`, `audit_events`, `invitation_requests`.
- [x] All ten `public.club_admin_*` privileged RPCs have `SECURITY DEFINER` and a fixed empty `search_path`.
- [x] All ten privileged RPCs deny EXECUTE to `anon` and `authenticated`, and allow EXECUTE to `service_role`.
- [x] Effective privilege assertions using `has_table_privilege` confirmed `anon` cannot SELECT any of the five tables and `authenticated` cannot INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES or TRIGGER on them.
- [x] Calling the invitation-begin RPC with a nonexistent/non-Chairman actor was rejected with insufficient privilege; no invitation was created.
- [x] Inspected the five SELECT policies: profile/membership/role visibility is self-scoped for active members or Chairman-authorized; invitation and audit reads are Chairman-authorized.
- [x] Confirmed schema-level SQL privileges show `anon` has no USAGE on `private`; `authenticated` has USAGE for policy helper calls. This does **not** prove the Supabase Data API Exposed schemas setting.
- [x] Supabase security advisor returned no findings.
- [x] Performance advisor currently reports six unused-index informational notices in this empty test project. These are not security findings and are not proof that indexes are unnecessary under production workload.

## What this verification does not prove

These are still release blockers and must not be marked passed based on catalog/SQL simulations:

- [ ] Dashboard confirmation that `private` is excluded from Data API Exposed schemas.
- [ ] Real HTTP/PostgREST requests using anonymous and separate authenticated test identities, including direct REST/RPC attempts. A repeatable suite is committed at `tests/phase-1-postgrest-smoke.mjs`; it could not execute in this environment because outbound DNS/network access was unavailable and test JWT fixtures are not configured.
- [ ] Real Auth Admin email delivery, correct redirect destination, unverified/mismatched email rejection, duplicate retry, provider failure, cancellation/expiry, and post-delivery database failure/reconciliation.
- [ ] Existing JWT/session behavior after suspension and revocation against protected resources.
- [x] Added database-backed per-identity limits in the review draft: 5 invitations/hour, 10 activation attempts/minute, and 60 other privileged mutations/minute. SQL threshold simulation passed; Edge Function integration and provider/gateway-wide abuse controls still require runtime verification.
- [ ] Verify configured `ALLOWED_ORIGINS` and `INVITE_REDIRECT_URL` in the target function environment and Supabase Auth redirect allowlist.
- [x] Added `docs/PHASE-1-INVITATION-RECOVERY-RUNBOOK.md` for safe manual recovery when a request remains `sending`.
- [ ] Independent review of the SQL and Edge Function, including the invitation delivery/checkpoint crash window and operational reconciliation runbook.
- [x] GitHub Actions non-deploying static checks passed: Node syntax check for the HTTP smoke suite and Deno type-check for the Edge Function.
- [ ] Full live HTTP/Auth integration suite and configured-runtime checks still require test identities and a deployed test-only endpoint.
- [ ] Final reviewer approval before merge.

## Safe release posture

PR #7 remains a draft. The Edge Function remains undeployed. No production migration has been prepared for execution or applied. Continue only in Union Test until all release blockers are evidenced and independently reviewed.

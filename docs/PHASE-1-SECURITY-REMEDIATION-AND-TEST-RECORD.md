# Phase 1 security remediation and test record

Status: **Draft implementation; not production-ready.** Work and all database experiments described here are limited to Union Test (`dzpquzfghapjodmrmavw`). Production `owvvimydkjsjlrmnzvdi` remains untouched.

## Implementation in review branch
- `supabase/review-drafts/identity_roles_review_draft.sql`: base identity schema/RLS draft.
- `supabase/review-drafts/transactional_identity_workflows_review_draft.sql`: invitation outbox, idempotency, invitation finalization/activation/cancellation, membership suspend/restore/revoke, role assignment/revocation, and serialized Chairman handover.
- `supabase/review-drafts/rate_limit_review_draft.sql`: database-backed per-identity rate limiting with an explicit deny-all policy on the private counter table.
- `supabase/review-drafts/auth_user_deletion_archive_review_draft.sql`: additive account-deletion lifecycle fix that preserves membership/role and invitation/audit history, revokes access, and blocks deletion of an active Chairman until handover.
- `supabase/functions/club-admin/index.ts`: review-only Edge Function routes; authenticates with Supabase Auth, resolves live membership/Chairman authority from database rows, bounds JSON request bodies to 16 KiB, validates invite redirect origin/scheme, enforces database-backed rate limits, and invokes service-only RPCs. **Do not deploy.**
- `tests/phase-1-postgrest-smoke.mjs`: real HTTP/PostgREST test suite requiring disposable test JWTs/fixtures; syntax checked in CI but live execution is skipped until test-only secrets are configured.
- `tests/phase-1-chairman-handover-concurrency.sh`: two-session psql race harness; syntax checked in CI, but live execution is skipped until the Union Test-only DB URL and project-ref variable are configured.
- `docs/PHASE-1-INVITATION-RECOVERY-RUNBOOK.md`: manual recovery for requests stranded in `sending` without automatic duplicate email delivery.
- PR #7 remains draft.

## Transaction boundary and recovery model
Postgres cannot share one transaction with Supabase Auth email delivery. The flow therefore uses:
1. A Chairman-authorized, idempotent database transaction creates a queued invitation request and audit event.
2. A single-winner claim changes the request to `sending`.
3. The server calls Auth Admin invite delivery.
4. The returned Auth user ID is checkpointed against the claimed request after validating its email.
5. A final database transaction writes pending membership + role assignment + invitation state + audit event together; a retry can finalize from the stored Auth user ID without automatically sending another email.
6. The invitee can activate only with the same Auth user ID, verified email, matching normalized address, and unexpired invitation.
7. Delivery failure records a bounded error code, not an invite token or raw provider response. If Auth delivery succeeds but the process crashes before checkpointing the Auth user ID, manual reconciliation is still required.

The Auth Admin call and database finalization are a distributed boundary, not a single ACID transaction. Requests stuck in `sending` after a process crash still need an operational reconciliation/retry procedure before release. Do not claim exactly-once email delivery.

## Union Test evidence so far
- Applied test-only migrations include `phase_1_identity_roles_review_test`, `phase_1_security_hardening_test`, `phase_1_transactional_identity_workflows_test`, `phase_1_membership_transition_result_fix_test`, the invitation compatibility/index hardening steps, `phase_1_rate_limit_private_deny_policy_test`, and `phase_1_auth_user_deletion_archive_test`. All were applied only to Union Test.
- Five identity/workflow tables have RLS enabled.
- Anonymous SELECT is absent; authenticated users have SELECT only and no direct table writes; all ten privileged RPCs are not executable by `anon` or `authenticated`, and are executable by `service_role`, with fixed empty `search_path`.
- Negative check rejected an actor without an active Chairman role.
- Transaction-rolled-back tests passed for invitation idempotency-key replay/conflict, timestamp trigger, suspend/restore/revoke transitions and audit, invitation queue claim, membership/role finalization, verified-email activation, replay denial, email mismatch, cancellation, expiry transition, and Chairman handover atomicity/single-Chairman invariant.
- Five rounds of paired independent SQL calls were launched concurrently. Every round produced one successful transfer and one denial; exactly one active Chairman remained after each round. Temporary test users/records were removed and verified absent.
- Additional rolled-back SQL checks passed for email mismatch, cancellation, and expiry state/audit transition. An Auth-user checkpoint was added so a retry can finalize the DB transaction without automatically resending an email once the checkpoint is saved.
- Added indexes for the five previously reported foreign keys; remaining performance-advisor notices are currently unused-index informational findings in this empty test database.
- Rolled-back invitation lifecycle simulation passed idempotent begin, claim, Auth-user checkpoint, finalization, verified activation, provider-failure state, cancellation and expiry.
- Rolled-back account-deletion test verified active-Chairman deletion is blocked until handover; other deleted accounts have membership/roles archived and revoked, invitation/audit history retained, and no temporary rows left behind.
- All temporary SQL test identities/data were rolled back or explicitly cleaned.
- Latest Supabase security advisor returned no findings after adding an explicit deny-all policy to the private rate-limit counter table. Performance advisor currently reports six unused-index informational notices in the empty test project; these are not security findings and need workload-aware review before production.

## Release blockers / evidence still required
- [ ] Confirm in Supabase Dashboard > Project Settings > Data API that `private` is absent from Exposed schemas. Catalog SQL cannot verify gateway configuration.
- [ ] Test actual HTTP/PostgREST denial using anonymous and authenticated API keys; catalog grants alone are not an end-to-end API test.
- [x] Run concurrent Chairman handover through two independent SQL requests; one winner / one denial and one active Chairman verified.
- [ ] Exercise real Auth Admin invite delivery, duplicate retry, email mismatch, expiry, cancellation, provider failure and post-send DB failure/reconciliation. SQL-only simulations are not a substitute for delivery testing.
- [x] Added a safe manual stale-`sending` reconciliation runbook; real Auth delivery/crash recovery still must be exercised before release.
- [x] Added database-backed per-identity rate limiting, request-size bounds, and redirect origin/scheme checks; SQL rate-limit threshold test passed.
- [ ] Verify real Edge Function CORS/redirect configuration and provider/gateway-wide abuse controls; function remains undeployed.
- [ ] Verify existing JWT behavior after suspension/revocation against protected resources; identity state must be checked server-side/RLS on every request.
- [x] Non-deploying GitHub Actions static review passed Node syntax checking for the PostgREST suite and Deno type-checking of the Edge Function.
- [ ] Independent human review and live HTTP/Auth integration evidence are still required.
- [ ] Only after the above passes, prepare a separate production migration for explicit approval.

No production migration has been prepared for execution or applied. No Edge Function has been deployed.

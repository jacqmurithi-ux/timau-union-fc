# Phase 1 security remediation and test record

Status: **Draft implementation; not production-ready.** Work and all database experiments described here are limited to Union Test (`dzpquzfghapjodmrmavw`). Production `owvvimydkjsjlrmnzvdi` remains untouched.

## Implementation in review branch
- `supabase/review-drafts/identity_roles_review_draft.sql`: base identity schema/RLS draft.
- `supabase/review-drafts/transactional_identity_workflows_review_draft.sql`: invitation outbox, idempotency, invitation finalization/activation/cancellation, membership suspend/restore/revoke, role assignment/revocation, and serialized Chairman handover.
- `supabase/functions/club-admin/index.ts`: review-only Edge Function routes; authenticates with Supabase Auth, resolves live membership/Chairman authority from database rows, uses allowlisted actions/roles, and invokes service-only RPCs. **Do not deploy.**
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
- Applied test-only migrations: `phase_1_identity_roles_review_test`, `phase_1_security_hardening_test`, `phase_1_transactional_identity_workflows_test`, and `phase_1_membership_transition_result_fix_test`.
- Five identity/workflow tables have RLS enabled.
- Anonymous SELECT is absent; authenticated users have SELECT only and no direct table writes; the eight privileged RPCs are not executable by `anon` or `authenticated`, and are executable by `service_role`.
- Negative check rejected an actor without an active Chairman role.
- Transaction-rolled-back tests passed for invitation idempotency-key replay/conflict, timestamp trigger, suspend/restore/revoke transitions and audit, invitation queue claim, membership/role finalization, verified-email activation, replay denial, email mismatch, cancellation, expiry transition, and Chairman handover atomicity/single-Chairman invariant.
- A two-request concurrent handover test on independent SQL calls produced one successful transfer and one denial; verification showed exactly one active Chairman, and temporary test users/records were then removed.
- Added indexes for the five previously reported foreign keys; remaining performance-advisor notices are currently unused-index informational findings in this empty test database.
- All temporary SQL test identities/data were rolled back.
- Security advisor returned no findings after workflow migration. Performance advisor reports five unindexed foreign keys (informational) and three currently unused indexes (informational); address index recommendations before production.

## Release blockers / evidence still required
- [ ] Confirm in Supabase Dashboard > Project Settings > Data API that `private` is absent from Exposed schemas. Catalog SQL cannot verify gateway configuration.
- [ ] Test actual HTTP/PostgREST denial using anonymous and authenticated API keys; catalog grants alone are not an end-to-end API test.
- [x] Run concurrent Chairman handover through two independent SQL requests; one winner / one denial and one active Chairman verified.
- [ ] Exercise real Auth Admin invite delivery, duplicate retry, email mismatch, expiry, cancellation, provider failure and post-send DB failure/reconciliation. SQL-only simulations are not a substitute for delivery testing.
- [ ] Add a safe stale-`sending` reconciliation process and operational retry controls.
- [ ] Add rate limiting / abuse controls, verify CORS origins and `INVITE_REDIRECT_URL` configuration, and review error handling.
- [ ] Verify existing JWT behavior after suspension/revocation against protected resources; identity state must be checked server-side/RLS on every request.
- [ ] Review all SQL and function code independently, run type/lint tests, and capture final evidence.
- [ ] Only after the above passes, prepare a separate production migration for explicit approval.

No production migration has been prepared for execution or applied. No Edge Function has been deployed.

# Phase 1 RLS and identity workflow test checklist

Run only against disposable Union Test until all checks pass. Never point this checklist at production.

## Catalog / grants (Union Test preliminary checks passed)
- [x] All five identity/workflow tables have RLS enabled.
- [x] No anon SELECT grants on identity/workflow tables.
- [x] Authenticated has SELECT only; no direct INSERT/UPDATE/DELETE on profile, membership, role, audit or invitation tables.
- [x] Privileged workflow RPCs deny EXECUTE to anon/authenticated and grant it to service_role.
- [ ] Confirm `private` absent from Data API exposed schemas (Dashboard confirmation required).
- [ ] Confirm actual HTTP/PostgREST behavior, not just catalog privileges.
- [ ] Recheck security advisor after all changes and record output.

## Identity authorization
- [x] Negative SQL test: nonexistent/non-Chairman actor cannot create an invitation.
- [ ] Anonymous API requests read no records.
- [ ] Active member reads own profile/membership/role only through real API.
- [ ] Invited, suspended and revoked identities cannot read protected resources through real API.
- [ ] Chairman reads only authorized records/audit events.
- [ ] Vice Chairman cannot assign roles or invite officials.
- [ ] User-editable metadata cannot grant privileges.
- [ ] Existing JWT after suspension/revocation cannot access protected records.

## Invitation lifecycle
- [x] Idempotency key replay returns same request; conflicting payload is rejected in rolled-back SQL test.
- [x] Queue claim, finalization, matching verified-email activation and replay denial passed in rolled-back SQL test.
- [ ] Real Auth Admin invitation email flow succeeds and destination is correct.
- [ ] Email mismatch and unverified email fail closed.
- [x] Expiry transition, cancellation and email-mismatch checks passed in rolled-back SQL tests.
- [ ] Revoked Auth identities and existing JWT behavior verified through real API.
- [x] Auth-user checkpoint and DB-finalization retry path implemented in draft.
- [ ] Test real Auth Admin failure, process crash before checkpoint, duplicate retries and DB finalization failure/recovery.
- [ ] No invite tokens, raw provider responses, or secret values are logged or stored.
- [ ] Rate limiting/abuse controls and CORS allowlist verified.

## Roles and concurrency
- [x] Suspend/restore/revoke transition and audit trail passed in rolled-back SQL test.
- [x] Invalid Chairman successor leaves the existing Chairman unchanged; handover transaction maintains exactly one active Chairman in sequential test.
- [x] Two independent SQL requests tested concurrently: one Chairman handover succeeded, the other was denied; exactly one active Chairman remained.
- [ ] Duplicate active role, invalid membership transition and self-role changes rejected.
- [ ] Timestamp trigger verified.
- [x] Added indexes for the five previously reported unindexed foreign keys; performance advisor now reports only unused-index informational findings on the empty test project.

## Final evidence
- [ ] Data API Exposed schemas screenshot/confirmation attached.
- [ ] Capture real HTTP/API tests, Auth delivery tests, concurrency output and advisor results.
- [ ] Review implementation, operational recovery runbook, and deploy configuration.
- [ ] No production operation before separate explicit production migration approval.
- [ ] Edge Function remains undeployed while PR is draft.

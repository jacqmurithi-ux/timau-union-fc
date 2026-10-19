# Phase 1 RLS and identity workflow test checklist

Run only against disposable Union Test. Never point this checklist at production. Latest SQL evidence is recorded in [automated verification](../docs/PHASE-1-AUTOMATED-VERIFICATION-2026-10-19.md). The real API suite is prepared at [phase-1-postgrest-smoke.mjs](phase-1-postgrest-smoke.mjs) and requires separate disposable test identities/JWTs.

## Catalog / grants — Union Test

- [x] All five identity/workflow tables have RLS enabled.
- [x] No effective anonymous SELECT and no direct authenticated table-write privileges on the five identity/workflow tables.
- [x] Ten privileged `public.club_admin_*` RPCs use SECURITY DEFINER and fixed empty `search_path`; EXECUTE denied to anon/authenticated and granted to service_role.
- [x] Rate-limit counter table is in `private`, RLS-enabled, has an explicit deny-all policy, and has no direct table grants to anon/authenticated/service_role.
- [x] Rate-limit SQL simulations passed all buckets: 5 invitations/hour (request 6 denied), 10 activations/minute (request 11 denied), and 60 admin mutations/minute (request 61 denied); temporary test counters were removed.
- [x] Latest Supabase security advisor returns no findings.
- [ ] Confirm in Supabase Dashboard that `private` is excluded from Data API Exposed schemas. SQL catalog checks cannot verify gateway configuration.
- [ ] Run the real HTTP/PostgREST suite against the test project with separate fixtures; do not substitute SQL grants checks for API results.

## Identity authorization / API

- [x] Negative SQL simulation: nonexistent/non-Chairman actor cannot create an invitation.
- [x] Latest-head non-deploying CI passed Node syntax check for the PostgREST smoke suite and Deno type-check for the Edge Function (run 37, commit `5a4b2b2`).
- [ ] CI skipped the live PostgREST step because Union Test JWT fixture secrets are not configured; add them as repository secrets and rerun to obtain real API evidence.
- [ ] Anonymous API SELECT denied through real HTTP.
- [ ] Active member reads their own profile only through real HTTP.
- [ ] Invited, suspended and revoked identities cannot read protected identity records through real HTTP.
- [ ] Chairman can read the seeded authorized fixtures and audit records through real HTTP.
- [ ] Vice Chairman cannot invite or assign/revoke roles through the Edge Function.
- [ ] User-editable Auth metadata cannot grant privileges through a real request.
- [ ] Existing JWT/session after suspension/revocation cannot access protected resources through real HTTP.
- [ ] Real API suite output attached to the PR. It could not run in this environment because outbound network/DNS was unavailable and separate test JWT fixtures are not configured.

## Invitation lifecycle

- [x] Idempotency key replay/conflict, queue claim, membership/role finalization, verified-email activation, replay denial, email mismatch, expiry, cancellation and audit transitions passed in prior rolled-back SQL simulations.
- [x] Auth-user checkpoint and retry-to-finalize logic implemented in the review draft.
- [x] Operational recovery procedure documented in [Phase 1 invitation recovery runbook](../docs/PHASE-1-INVITATION-RECOVERY-RUNBOOK.md).
- [ ] Real Auth Admin email delivery and correct destination confirmed.
- [ ] Real mismatched/unverified email rejection confirmed through Auth/API.
- [ ] Provider failure, duplicate retry, cancellation/expiry, post-send DB failure, crash-before-checkpoint and recovery tested end-to-end.
- [ ] Verify no invite tokens, raw provider responses, access tokens or secrets are logged/stored.
- [ ] Verify Edge Function returns HTTP 429 at rate limits and fails closed with 503 if rate-limit RPC is unavailable.

## CORS / redirects / abuse controls

- [x] Added database-backed limits: 5 invitation attempts/hour, 10 activation attempts/minute, 60 other privileged mutations/minute, per authenticated identity.
- [x] Request body is capped at 16 KiB; non-JSON bodies are rejected.
- [x] Requests with an Origin are rejected if the allowlist is absent or does not match.
- [x] Invitation redirect must be HTTPS (localhost HTTP only for development), contain no embedded credentials, and have an origin listed in `ALLOWED_ORIGINS`.
- [ ] Confirm production-like test `ALLOWED_ORIGINS` and `INVITE_REDIRECT_URL` values in function secrets; the function is intentionally undeployed.
- [ ] Confirm `INVITE_REDIRECT_URL` is also allowed in Supabase Auth URL configuration.
- [ ] Add/verify provider/gateway-level abuse controls and monitoring; per-identity rate limits do not throttle anonymous traffic before authentication.
- [ ] Test CORS preflight and denied-origin responses against a deployed test-only endpoint before any release.

## Roles / concurrency

- [x] Suspend/restore/revoke transition and audit trail passed in prior rolled-back SQL test.
- [x] Chairman handover serialized with transaction advisory lock and backed by unique active-Chairman index.
- [x] Two independent SQL requests yielded one handover success and one denial; exactly one active Chairman remained. This is request-level concurrency evidence, not a repeatable multi-session stress test.
- [x] Invalid Chairman successor, duplicate active Chairman assignment and invalid lifecycle/revocation transitions were rejected in prior SQL simulations.
- [ ] Repeat handover race test with a controlled, repeatable multi-session harness and captured evidence.
- [ ] Verify role-change authorization and existing JWT behavior with separate identities through the real endpoint.

## Final review / release gate

- [x] GitHub Actions non-deploying static-review workflow passed: Node syntax, Deno type-check, review-draft placement, and no production URL/service-role secret in the tested artifacts.
- [x] Edge Function remains undeployed; PR #7 remains draft.
- [ ] Independent human reviewer reviews SQL, Edge Function, rate limiter, and recovery runbook and records approval.
- [ ] Attach Data API Exposed schemas confirmation and real HTTP/Auth integration evidence.
- [ ] No production operation before separate explicit production migration approval.

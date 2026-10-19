# Phase 1 security remediation and test record

Status: **Not production-ready.** Test-only schema hardening is recorded; production remains unchanged.

## Scope and environment
- Disposable test project: Union Test, `dzpquzfghapjodmrmavw`.
- Production project: `owvvimydkjsjlrmnzvdi` — not modified.
- Test migrations recorded: `phase_1_identity_roles_review_test`, `phase_1_security_hardening_test`.

## Remediations represented in the revised SQL draft
- Removed `contact_email` from broadly readable profile data.
- Revocation requires both `revoked_at` and `revoked_by`.
- Timestamp trigger uses `clock_timestamp()`.
- RLS is enabled on all four tables and client write grants remain revoked.
- At most one active Chairman is enforced by a partial unique index.

## Trusted workflow status
The Edge Function in `supabase/functions/club-admin/index.ts` is intentionally a fail-closed review scaffold. It authenticates the caller with Supabase Auth, resolves active membership and Chairman role from database records, allow-lists roles, rejects self-assignment, and refuses to invite until the atomic database workflow exists. It does **not** claim to complete invitation lifecycle.

Before implementing invitation, add a reviewed transactional outbox/RPC design that:
1. Creates a pending invitation record, membership, role assignment, idempotency key, and audit event atomically.
2. Lets the server worker call Auth Admin invite only after the pending transaction commits.
3. Records invite sent/failed and supports safe retry/compensation without persisting invite tokens.
4. Activates only after verified Auth email matches the invitation; invitation cannot be reused, expired, cancelled, or revoked.
5. Implements suspend/restore/revoke and Chairman handover in database transactions with actor checks and audit events.
6. Makes client writes impossible and does not expose service secrets.

## Required checks still outstanding
- Supabase Dashboard > Project Settings > Data API: confirm `private` is not in Exposed schemas. SQL alone cannot establish the API gateway setting.
- Test real REST/API requests for anonymous, active member, invited, suspended, revoked, and Chairman identities.
- Test trigger timestamp changes.
- Test two concurrent Chairman handovers using separate sessions.
- Test invitation email mismatch, expiry, cancellation, replay, duplicate retry, Auth Admin failure and recovery.
- Test existing JWT after suspension/revocation.
- Verify the post-hardening table shape and security advisor on Union Test.
- Review Edge Function error paths, rate limits, audit redaction, and CORS origin before deployment.

No production migration, Edge Function deployment, or production auth configuration change is authorized by this draft.

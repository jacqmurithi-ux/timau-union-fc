# Phase 1 RLS and identity workflow test checklist

Run only against disposable Union Test until all checks pass. Never point this checklist at production.

## Catalog / grants
- [ ] All four tables have RLS enabled.
- [ ] No anon SELECT/INSERT/UPDATE/DELETE grants.
- [ ] Authenticated has SELECT only; no direct writes to profile, membership, role, audit.
- [ ] `private` absent from Data API exposed schemas (Dashboard confirmation required).
- [ ] SECURITY DEFINER helpers have safe owner, fixed empty search_path and least-privilege EXECUTE grants.
- [ ] No secret key or invitation token appears in browser bundle, logs or audit details.

## Identity authorization
- [ ] Anonymous request reads no records.
- [ ] Active member reads own profile/membership/role only.
- [ ] Invited, suspended and revoked identities cannot read business data.
- [ ] Active Chairman reads authorized member records and audit events only.
- [ ] Vice Chairman cannot assign roles or invite officials.
- [ ] User-editable metadata cannot grant privileges.
- [ ] Existing JWT after suspension/revocation cannot access protected records.

## Invitation lifecycle
- [ ] Chairman-only invite; invalid role/email rejected.
- [ ] Self-assignment and unauthorized role elevation rejected.
- [ ] Verified email must match normalized invitation email.
- [ ] Expired/cancelled/revoked/replayed invite fails closed.
- [ ] Duplicate invite/retry is idempotent.
- [ ] Auth Admin failure and database failure recover without active orphan membership.
- [ ] All transitions append safe, actor-attributed audit events.

## Roles and concurrency
- [ ] Duplicate active role rejected.
- [ ] Only one active Chairman even under concurrent transactions.
- [ ] Chairman handover is atomic; forced failure leaves original Chairman intact.
- [ ] Non-active membership cannot receive active role.
- [ ] Revocation requires actor and revokes all role assignments transactionally.
- [ ] Trigger updates `updated_at` on ordinary row updates.

## Final evidence
- [ ] Capture test output, migration IDs and advisor results.
- [ ] Review source and deployment configuration.
- [ ] No production operation before explicit production migration approval.

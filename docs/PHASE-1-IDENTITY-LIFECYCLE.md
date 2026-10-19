# Phase 1 — Identity, membership lifecycle, and role governance

**Status:** Design/review specification only. No database operation is approved by this document.  
**Production project reference:** `owvvimydkjsjlrmnzvdi`  
**Rule:** Do not execute review SQL against production. Validate only against a separately verified disposable project, then prepare a distinct production migration for explicit owner approval.

## Decisions captured

- Email invitations only; no public self-registration.
- The Chairman may initiate invitations and manage roles through a trusted server-side operation. The Vice Chairman has deputy responsibilities but has no role-assignment authority by default.
- Role authorization comes from current database state and RLS-protected data, never user-editable Auth metadata or UI visibility.
- At most one active Chairman is allowed at a time. A Chairman handover is a single trusted transaction: revoke the outgoing active assignment, assign the incoming active member, and append audit events. The partial unique index is the concurrency-safe backstop. A failed transaction must leave the prior Chairman assignment intact.
- A member must be active before they can read their profile, membership, or role assignments through the proposed policies. Suspended and revoked identities receive no self-read path to these tables. Any minimal invitation-status page, if later required, must be a separately designed narrow path that exposes no business data.
- Only trusted server-side operations may create or change memberships, role assignments, or audit events. No browser client receives a service-role/secret key.
- Audit records are append-only through the trusted API contract. Store only allow-listed operational metadata; never store passwords, access/refresh tokens, invitation links, secret keys, or full request bodies.

## Membership lifecycle

Allowed status model:

| Status | Required timestamps | Authorization |
|---|---|---|
| invited | `activated_at IS NULL`, `revoked_at IS NULL` | No business-data access |
| active | `activated_at IS NOT NULL`, `revoked_at IS NULL` | Access only as granted by role and RLS |
| suspended | `activated_at IS NOT NULL`, `revoked_at IS NULL` | No business-data access |
| revoked | `revoked_at IS NOT NULL`; activation may be null if revoked before acceptance | No business-data access |

State transitions must be implemented by trusted transactional operations, not direct table updates:

- `invited → active`: only after verified identity/email binding and valid invitation.
- `invited → revoked`: invitation cancelled before acceptance.
- `active → suspended`: authorized Chairman operation; record actor and reason code.
- `suspended → active`: explicit authorized restoration; retain history.
- `active/suspended/invited → revoked`: authorized revocation; revoke role assignments in the same transaction.
- Repeated requests must be idempotent or return a controlled conflict; they must not create duplicate active assignments or duplicate successful activation.

Every protected request must check current membership and role state from the database/RLS. UI state or an unrefreshed role claim is not the authorization boundary.

## Invitation acceptance contract (design only)

1. A trusted server endpoint verifies the caller is an active Chairman before creating an invitation.
2. Normalize the destination email; validate against the allow-listed role keys; reject attempts to assign the role to the caller or choose an unauthorized role.
3. Use Supabase Auth's server-side invitation mechanism. Never expose the service-role/secret key to the browser.
4. Create a pending membership and role assignment through one controlled workflow; persist only the normalized invited email and minimal audit metadata. Do not trust a role, user ID, or email supplied back by the browser without server-side verification.
5. Acceptance requires a verified Auth identity whose verified email matches the invitation email using the agreed normalization rule. A mismatch, expired/cancelled/revoked invitation, or already-consumed invitation must fail closed.
6. Activate membership and record `activated_at` only after successful binding. Use a transaction or an idempotent state machine to avoid partial activation. Never let an invitee select/change their assigned role.
7. Emit audit events for invite requested, invite sent/failed, accepted, rejected, cancelled, and role assigned/revoked. Redact credentials and invitation tokens.

**Open implementation choice:** whether the trusted operation is an Edge Function using server-side Auth Admin API or a carefully constrained database operation. Prefer a server-side Edge Function for the Auth invitation call; database writes must still be atomic and least-privileged. This choice requires a separate implementation/security review.

## Role assignment and handover contract

- Allow only the role keys in `docs/ROLE-PERMISSION-MATRIX.md`.
- Chairman-only role governance is enforced server-side, not by hidden UI buttons.
- Vice Chairman cannot assign, elevate, or revoke roles unless a later approved design explicitly grants that authority.
- Reject assigning a role to a non-active membership.
- Prevent self-promotion and prevent the actor from granting a higher role to themselves.
- One active assignment per role per member; at most one active Chairman across the club.
- For handover, validate the incoming identity and active membership, revoke the outgoing Chairman assignment and create the incoming assignment in one transaction. Require explicit confirmation and record before/after actor and target IDs in audit metadata. The unique index must cause a conflict rather than allow two Chairmen if concurrent operations race.
- Define a recovery path if the sole Chairman loses access. Recovery must be an out-of-band, verified administrative procedure—not a public RPC or self-service role escalation.

## Audit write contract

Allow-list fields such as `request_id`, `reason_code`, `target_user_id`, `target_membership_id`, `role_key`, and state transition names. Do not persist passwords, tokens, invitation URLs, raw headers, or arbitrary client-provided JSON. The client has no insert/update/delete permissions. Trusted code validates action names and inserts audit records in the same transaction as the state change where possible. Access to audit events is Chairman-only by default and must itself be tested.

## SQL review draft

`supabase/review-drafts/identity_roles_review_draft.sql` is still a review artifact, not a migration. It intentionally fails on pre-existing objects instead of pretending `IF NOT EXISTS` proves their definitions match. Use a clean disposable project for initial validation. Inspect the Data API exposed-schema configuration separately; creating a `private` schema does not automatically prove it is excluded from the Data API.

## Test gates before any migration

- [ ] Confirm test project reference in the Supabase dashboard; confirm it is disposable and not production.
- [ ] Check Supabase changelog/current docs, installed CLI version, and supported SQL behavior.
- [ ] Execute the draft only in that disposable project after review.
- [ ] Verify RLS is enabled on all four public tables and anonymous access is denied.
- [ ] Verify active member can read only their own profile/membership/roles; suspended/revoked/invited users cannot read business identity data.
- [ ] Verify Chairman can read authorized membership/role/audit rows and non-Chairman officials cannot read other members or audit events.
- [ ] Verify direct REST requests cannot write membership, roles, or audit rows.
- [ ] Verify private schema is not exposed via Data API and inspect owner/grants for each SECURITY DEFINER function.
- [ ] Verify updated_at changes on updates.
- [ ] Verify duplicate active Chairman inserts fail, including two concurrent attempts.
- [ ] Verify membership and role lifecycle constraints reject inconsistent timestamps.
- [ ] Test invitation mismatch, unverified email, expired/reused/cancelled invitation, existing Auth account, revoked membership, repeated acceptance, and role tampering.
- [ ] Test Chairman handover success, rollback on failure, concurrent handover attempts, and recovery procedure.
- [ ] Verify audit redaction, append-only behavior, and transaction consistency.
- [ ] Record actual results/evidence; do not mark checklist items passed merely because the SQL appears correct.

## Release gate

No production SQL execution until the static review is complete, the test suite passes on the disposable project, a separate executable migration has been reviewed, and the owner explicitly approves that production change.

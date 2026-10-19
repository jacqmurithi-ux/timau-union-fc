# Timau Union FC — Role and Permission Matrix

Status: Phase 1 implementation baseline for review  
Scope: Authentication, membership, role governance and initial data boundaries  
Hosting: GitHub Pages from `main`; no Vercel  
Backend: Supabase Auth and PostgreSQL RLS

## 1. Identity and account lifecycle

- Management accounts are invitation-only. Public self-registration remains disabled.
- Supabase Auth verifies identity; a successful login alone does not grant club access.
- Access requires an active membership and an active role assignment.
- Players do not have management accounts.
- Role assignments are changed only through a trusted, authorized operation and must be audited.
- Revoking membership or role access must immediately deny subsequent protected data requests, including requests made from an existing browser session.
- Never place a service-role key or other privileged secret in browser code.

## 2. Permission principles

1. Deny by default.
2. Every request is checked server-side/database-side; navigation visibility is only a usability feature.
3. Apply least privilege by capability, record scope, field sensitivity and action.
4. Separate read, create, edit, delete, approve, publish, export, finance, role-management and audit capabilities.
5. Never trust a role name or user ID supplied by the browser without validating it against trusted records.
6. A role does not automatically confer access to confidential welfare, private contacts, identity documents, finance or payment data.
7. Public website reads use only purpose-built public-safe access paths.
8. Sensitive state transitions must use trusted operations that validate the previous state, actor, approval and audit requirements.

## 3. Initial role matrix

Legend: **Scoped** means only assigned operational records/fields. **Restricted** means no access unless a separate explicit capability is granted.

| Area | Chairman | Vice Chairman | Secretary | Team Manager | Treasurer | Coach | Sponsor Lead | Media Team |
|---|---|---|---|---|---|---|---|---|
| Sign in | Invited account | Invited account | Invited account | Invited account | Invited account | Invited account | Invited account | Invited account |
| View own profile/role | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| View official directory | Yes | Scoped | Scoped | Scoped | Scoped | Scoped | Scoped | Scoped |
| Invite/revoke officials | Yes | No, unless separately authorized | No by default | No by default | No by default | No by default | No by default | No by default |
| Assign/elevate roles | Yes, trusted workflow | No | No by default | No by default | No by default | No by default | No by default | No |
| Player register | Oversight | Scoped | Maintain scoped records | Maintain team-scoped records | No by default | Squad-scoped | No by default | Public-safe fields only when approved |
| Private player details/welfare | Explicitly authorized only | Restricted by default | Minimum required, separately scoped | Minimum required, separately scoped | No | Restricted | No | No |
| Fixtures/results | Yes | Scoped | Scoped | Maintain | Read only if needed | Team-scoped | No by default | Draft/report inputs only |
| Training/attendance | Oversight | Scoped | Scoped | Maintain | No by default | Maintain team scope | No | No by default |
| News drafts | Review | Review/deputy | Scoped | Match-report input | No by default | Match-report input | Sponsor-related input | Create/edit assigned drafts |
| Approve/publish news | Final approval | Only with valid deputy authority when Chairman unavailable | No by default | No by default | No by default | No by default | No by default | No |
| Documents | Authorized scope | Authorized scope | Maintain non-financial official records | Team documents | Financial documents only | Training/team documents | Sponsor documents | Media assets only |
| Finance and financial reports | Explicitly authorized oversight | No automatic access | No by default | No by default | Maintain and reconcile | No | No automatic access | No |
| Equipment/assets | Scoped | Scoped | Scoped | Team equipment | Finance fields only if authorized | Issue/use records in scope | No by default | No by default |
| Sponsor records | Oversight | Scoped | Scoped if authorized | No by default | Financial fields only if authorized | No | Maintain sponsor scope | Approved public assets only |
| Reports/exports | Only permitted data | Only permitted data | Only permitted data | Only permitted data | Financial scope | Team scope | Sponsor scope | Media scope |
| Audit history | Authorized audit scope | Restricted unless authorized | Restricted unless authorized | Restricted unless authorized | Finance audit scope | Restricted | Restricted | Publication actions in scope |
| Club Store (future Phase 5) | Explicitly authorized | No automatic access | No automatic access | No automatic access | Payment reconciliation if authorized | No | Product/sponsor scope if authorized | Approved marketing content only |

This matrix is a safe starting point, not a grant of access by itself. Any unresolved capability remains denied until a documented permission and test are added.

## 4. Specific governance controls

### Chairman and role assignment
- The Chairman can initiate official invitations and role changes through a trusted backend operation.
- Another role manager is allowed only after explicit delegation has been represented in trusted data and tested.
- The Vice Chairman does not receive role-management authority from deputy status.
- Users cannot edit their own role assignment or grant permissions to themselves.
- Invitation acceptance binds the intended invited email/identity and never lets the invitee choose their role.

### Vice Chairman publication delegation
- Deputy publication is a separate capability from role administration.
- Publication must require a valid, explicit delegation and verified Chairman-unavailable state according to an approved workflow.
- Approval/publication actor and timestamp are audited.
- This capability grants no automatic access to finance or confidential records.

### Finance and opening balances
- Treasurer handles authorized finance records.
- Opening balance requires separate Treasurer proposal and Treasurer/Chairman confirmations, with distinct actors; it remains pending until both confirmations exist.
- Corrections are separate logged adjustments, not edits that rewrite confirmed history.
- Finance schema and posting workflows will be implemented in a separate reviewed stage.

### Inventory and reports
- Inventory uses scoped access. The Chairman designates a backup maintainer.
- Significant stock adjustments and disposals require independent review; the recorder cannot approve their own action.
- Authorized officials may export inventory reports only for data/fields they are already permitted to access.
- Stocktakes are quarterly and at season changes/handover.
- Report/export permissions never expand underlying access.

## 5. Initial schema boundaries

Phase 1 should establish only the identity/security foundation:

- `user_profiles`: non-secret profile fields linked one-to-one to `auth.users`.
- `club_memberships`: a user's active/suspended/revoked membership state for this club.
- `role_assignments`: trusted role assignments; users cannot write their own assignments.
- `audit_events`: append-only audit trail written only by trusted database/backend operations.

Business modules will be added only with their own permission map and RLS tests. Sensitive fields should be separated into restricted tables or returned through narrow, purpose-built views/functions. Do not put public and confidential fields into one broad public-readable record.

## 6. RLS implementation and testing gates

Before applying any migration:

- Review schema, grants, policies, functions, ownership and fixed `search_path`.
- Check for policy recursion and ensure helper functions cannot be abused to elevate privileges.
- Explicitly revoke unwanted privileges and grant only required operations.
- Verify anon cannot read private records and cannot create an official account.
- Verify authenticated users without active membership are denied.
- Verify a user cannot alter their own role or access another official's restricted records.
- Verify Vice Chairman cannot assign roles and Media Team cannot self-publish.
- Verify revoked users are denied on direct API requests.
- Verify audit records cannot be rewritten by ordinary users.
- Run positive and negative tests in a non-production Supabase project before production review.

## 7. Delivery sequence

1. Identity and role governance schema plus RLS review.
2. Invitation/revocation trusted backend operations and sign-in UI.
3. Player register and private-field separation.
4. Fixtures, results, training and attendance.
5. News workflow with trusted approval/publication.
6. Documents, sponsors, equipment/assets and reports.
7. Finance and dual-confirmed opening balances.
8. Club Store in Phase 5, with private orders and trusted payment verification.

No migration is applied by this document. Each SQL change must be shown for review before execution.

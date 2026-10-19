# Timau Union FC — Authentication and Security Design

**Status:** Approved design specification; implementation remains on hold  
**Repository:** `jacqmurithi-ux/timau-union-fc`  
**Hosting:** GitHub Pages for the public static website  
**Planned backend:** Supabase Auth, PostgreSQL, and Row Level Security (RLS)

## 1. Purpose and scope

This document defines the planned invitation-only access model, official roles, authorization boundaries, RLS design requirements, and security tests. Approval covers design and documentation only. It does **not** authorize authentication code, database migrations, SQL/RLS changes, Supabase configuration changes, production data changes, or deployment of management functionality.

The Phase 1 website is static. A hidden page, login link, disabled button, or client-side role check is not a security boundary.

## 2. Architecture and trust boundaries

- **Public website:** serves only information approved for public release. It must not expose private player records, personal contact details, financial data, welfare records, confidential documents, or management operations.
- **Private management:** planned under `/app/`; requires an authenticated, active, authorized club official. Direct URLs and API requests must be protected just like UI navigation.
- **Supabase Auth:** verifies identity; sign-in alone does not grant club access.
- **PostgreSQL RLS:** enforces row-level access for protected data. Grants, views, functions/RPCs, storage policies, and any privileged server-side paths must also be reviewed.
- **Least privilege:** every operation must check active membership, role/capability, record scope, and requested action. Deny by default when these cannot be verified.
- Never put service-role keys, database passwords, or other privileged secrets in browser code.

## 3. Invitation-only account lifecycle

There is no public self-registration. Players do not receive management accounts, passwords, invitations, or login access.

1. The Chairman, or a role manager explicitly authorized by the Chairman, initiates an invitation for a named official.
2. The invitation uses the approved email-based process and is bound to the intended identity and club.
3. Invitations expire or can be revoked; acceptance cannot grant roles or privileges chosen by the invitee.
4. After sign-in, the system verifies identity, active club membership, assigned role, and permitted scope.
5. Access is limited to the official's authorized records and actions.
6. When access is no longer needed, an authorized role manager revokes it. Subsequent protected operations must fail, including requests from an old browser session.
7. Invitations, acceptance, revocation, and role changes should be auditable.

Account recovery and the exact invitation implementation require review before coding. Public sign-up must not be added as a fallback.

## 4. Roles and permissions

Role names indicate intended scope, not blanket access to all data.

| Role | Intended scope | Limits |
|---|---|---|
| Chairman | Overall club administration, role assignment, access oversight, final publication approval | Sensitive actions remain authenticated, scoped, and audited |
| Vice Chairman | Deputy duties and explicitly delegated operational actions; may approve and publish news when the Chairman is unavailable under the approved deputy arrangement | Cannot independently assign/elevate roles; no automatic financial or confidential-data access |
| Secretary | Authorized official records, documents, player registration, club administration | No automatic finance or role-management authority |
| Team Manager | Team operations, authorized player records, fixtures, results, attendance | No automatic finance or role-management authority |
| Treasurer | Financial records and authorized financial administration/reports | No automatic role-management or publication authority |
| Coach | Authorized squad information, training, attendance, match preparation | No automatic finance, confidential welfare, or role-management access |
| Sponsor Lead | Sponsor records and sponsor-related activity | No automatic access to private player or unrelated financial records |
| Media Team | Draft/edit assigned news, stories, photos, match reports and media content | Cannot publish unapproved content; no automatic access to finance, private player details, welfare records, or role management |
| Player | No account | No private management login |
| Supporter/public visitor | Public website only | No private management access |

### Permission rules

- The Chairman may assign official roles. Another role manager may do so only after explicit authorization is granted and recorded.
- The Vice Chairman cannot independently assign or elevate official roles.
- The Secretary, Team Manager, or another explicitly authorized official may maintain player records only within assigned scope.
- Multiple roles must not silently bypass restrictions. Effective permissions must be calculated and tested deliberately.
- Users cannot grant themselves roles, change trusted permission claims, or rely on client-supplied role names.
- Missing, unknown, or unverifiable membership/permission means denial.

## 5. Publication and deputy authority

Content creators, including the Media Team, may draft and edit within scope; editing does not imply publication authority.

1. Content starts as an unpublished draft.
2. An authorized reviewer checks accuracy, privacy, and suitability for public release.
3. The Chairman retains final approval.
4. When the Chairman is unavailable, the Vice Chairman may approve and publish under the explicitly delegated deputy publication authority approved for this project.
5. The approval and publication must be attributable to the responsible official and recorded in audit history.
6. This delegation applies to publication only; it does not grant role-assignment powers or unrelated access to private data.
7. The backend must reject unapproved publication attempts, including direct API/database requests.
8. Corrections and withdrawal must follow an authorized, auditable workflow.

Before implementation, define how the Chairman's unavailability and valid deputy authority are represented and verified. Do not infer broad privileges from the Vice Chairman role alone.

## 6. Data Centre and Reports

The Data Centre is for **all authorized officials**, not only the Chairman or administrators. Each official can access only permitted sections, records, fields, and actions. Categories include player registration, officials/roles, fixtures/results, training/attendance, documents, news/media, data quality, and controlled exports.

Reports may include player registration, training and attendance, fixtures/results, media activity, data quality, financial information, and Club Store summaries. The Reports page grants no blanket access: authorization must cover the underlying rows and fields. Exports must enforce the same restrictions and minimize personal information.

Confidential documents, welfare information, financial records, and role administration require explicit permissions of their own.

## 7. Club Store security boundaries

If implemented, public visitors may view approved product information and use an approved order workflow. Order administration and payment records are private.

- Restrict order management to explicitly authorized officials.
- Restrict payment verification and reconciliation to the Treasurer or another explicitly authorized financial official.
- Keep customer contacts, order details, payment references, and internal notes private; prevent cross-customer order access by changing an identifier.
- Never store M-Pesa PINs, passwords, card secrets, or unnecessary payment credentials.
- A browser redirect, customer message, or screenshot is not proof of payment. Only trusted provider verification may mark an order paid.
- Protect order lookup, status changes, refunds, exports, and future payment integrations.
- No payment provider, integration, schema, or payment code is authorized by this document.

## 8. RLS and backend policy requirements

No executable SQL is included or authorized. Before implementation, inventory tables, views, functions/RPCs, grants, storage buckets, and intended public data. Design policies to enforce:

- Authenticated identity verified by Supabase Auth.
- Active membership in the correct club.
- Trusted role/capability, never a client-provided role value.
- Correct club and record scope.
- Separate authorization for read, create, update, delete, approve, publish, export, and role administration.
- Field-level sensitivity handled with safe data models, restricted views, or trusted operations where row-level policies alone are insufficient.
- No broad grants or privileged paths that bypass intended policies.
- Default denial for missing membership, unknown role, invalid scope, or failed checks.
- Appropriate audit events for important actions without logging secrets.
- Public queries limited to deliberately public content, not broad access to private tables.

RLS must be tested alongside grants, views, functions, and storage access; enabling RLS alone is not sufficient.

## 9. Security and access-denial test plan

These are future acceptance tests; they have **not** been executed.

| Test | Expected result |
|---|---|
| Anonymous visitor requests private management data | Denied |
| Visitor attempts public self-registration | No public registration path; cannot create an official account |
| Player attempts management login | No player account/login route exists |
| Authenticated person lacks active club membership | Protected club data denied |
| User changes a URL or record ID to access a restricted row | Denied |
| Official from another club requests private data | Denied |
| Vice Chairman attempts to assign/elevate a role | Denied |
| Ordinary official changes their own role/permissions | Denied |
| Media Team publishes a draft without approval | Denied |
| Vice Chairman publishes with valid delegated authority while Chairman is unavailable | Allowed and audited |
| Vice Chairman attempts role assignment under publication delegation | Denied |
| Media Team requests finance, welfare, or confidential player data without authorization | Denied |
| Official edits player records outside assigned scope | Denied |
| Report/export includes restricted rows or fields | Restricted data omitted or request denied |
| Revoked official sends a protected request using an old session | Denied |
| Direct REST/RPC/database request bypasses UI controls | Backend authorization denies it |
| Public request tries to retrieve private documents or orders | Denied |
| Unauthorized official reads or changes store/payment records | Denied |
| Client claims an order is paid without trusted verification | Order remains unpaid/pending |
| Unauthorized user changes content approval/publication status | Denied |
| Authorized sensitive action succeeds | Relevant audit event recorded |
| Unauthorized user alters audit history | Denied |

Test positive and negative cases across anonymous and authenticated sessions, multiple roles, cross-club boundaries, direct API requests, and revoked access. A successful UI test alone is insufficient.

## 10. Audit, privacy, and operational review

Audit invitations, role changes, player-record changes, fixture/result changes, publication approvals, content publication/withdrawal, financial actions, sensitive exports, and store/payment administration as appropriate. Restrict audit access and prevent ordinary users from rewriting history to conceal actions. Do not log credentials, payment secrets, or unnecessary personal information.

Before launch, separately review retention, backup/recovery, account recovery, incident response, rate limiting, file-upload validation, and privacy practices.

## 11. Implementation gates

- [ ] Approve a capability-by-capability permission matrix.
- [ ] Define how delegated Vice Chairman publication authority is verified.
- [ ] Inventory tables, views, RPC/functions, storage, grants, and public data.
- [ ] Review proposed migrations and SQL/RLS policies before execution.
- [ ] Review invitation, revocation, recovery, and audit designs.
- [ ] Define sensitive data and field-level exposure rules.
- [ ] Review Club Store order and payment trust boundaries before implementation.
- [ ] Run and document positive and negative authorization tests in a safe test environment.
- [ ] Obtain separate explicit authorization for implementation.

**Current state:** design approved; implementation remains on hold. This document authorizes no authentication code, migration, RLS policy, Supabase configuration, production data, or deployment change.

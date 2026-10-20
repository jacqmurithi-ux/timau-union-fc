# Timau Union FC — Signup, Platform Approval and Role Assignment

Status: Implementation/security gate. This document does not claim that authentication or authorization is deployed.

## Required user journey

1. Public visitor can create an account through the signup page and verify their email.
2. A successful signup creates an identity only. It does not create an active club membership or grant any club role.
3. Every new request starts as pending and sees only a pending-review screen until approved.
4. A separately provisioned Platform Admin reviews pending requests in a protected platform dashboard.
5. Platform Admin can approve/reject access, suspend/revoke access, and assign/revoke an allowed club role. Every decision records actor, target, timestamp, action and reason.
6. A user receives protected access only when email verification, approval/active membership, and an active role assignment are all valid.
7. Revoked/suspended access must fail at database/backend boundaries even if the browser still has a session.

## Roles and authority boundaries

- Platform Admin is a platform-level authority, distinct from the club's Chairman and club roles.
- Platform Admin is never self-selected during signup and must be provisioned through a reviewed trusted bootstrap process.
- Platform Admin can approve membership and assign club roles through the protected dashboard.
- Chairman and Vice Chairman do not automatically become Platform Admins.
- Vice Chairman cannot assign or elevate roles.
- Signup form fields, user-editable metadata, URL parameters and browser state are never authoritative for roles or approval status.
- Define a deliberate break-glass/recovery procedure for Platform Admin loss before production launch.

Allowed club roles for initial release: chairman, vice_chairman, secretary, team_manager, treasurer, coach, sponsor_lead, media_team.

## Dashboard requirements

- Pending requests queue with verified email, display name, signup time and status.
- Request detail with Approve, Reject, Suspend/Restore and Assign/Revoke Role actions.
- Role changes require confirmation and a reason; show current and historical assignments.
- Prevent duplicate active assignments and invalid role values.
- Prevent accidental removal of the last Platform Admin; require a reviewed handover/recovery path.
- Display clear statuses: Pending verification, Pending approval, Active, Rejected, Suspended, Revoked.
- Dashboard is mobile-first and exposes no credentials, tokens, or service-role key.
- All write actions must report server-confirmed outcomes; a successful button click alone is not proof of authorization.

## Security architecture requirements

- Supabase Auth verifies identity; PostgreSQL RLS and trusted server-side functions enforce authorization.
- No service-role key or other privileged secret may appear in static HTML, JavaScript, public GitHub files, or client environment variables.
- Use a non-exposed schema for authorization helpers and privileged functions, with fixed empty search_path, fully qualified object names, explicit caller checks, least-privilege grants and verified function ownership.
- Client-side users receive no direct INSERT/UPDATE/DELETE privileges on membership, role assignment, approval state, platform administrator registry, or audit tables.
- Use trusted, transaction-safe functions for approve/reject/suspend/revoke/role assignment and append audit events in the same transaction.
- Protect every private data query independently of navigation visibility.
- Public pages query only public-safe views and never read private management tables.
- Rate-limit signup and avoid revealing whether an email is registered in error messages.
- Email verification and pending approval are separate states.
- Define session refresh/revocation behavior and test access after suspension or revocation.

## Migration review blockers

The existing supabase/review-drafts/identity_roles_review_draft.sql is a draft only and does not implement trusted signup approval or role writes. It currently models membership status as invited/active/suspended/revoked, has Chairman-only role-management checks, and does not model a distinct Platform Admin authority. Do not apply it as-is for the requested workflow.

Before applying any migration:
1. Design the separate platform-admin authority and safe initial bootstrap/recovery.
2. Add pending approval/rejection states and the trusted transaction-safe workflows.
3. Review all grants, RLS policies, SECURITY DEFINER ownership/search paths and Data API exposed schemas.
4. Apply only to a verified disposable Union Test project after reviewing the exact SQL.
5. Run positive and negative tests using separate identities, including anonymous, verified-but-pending, rejected, suspended, revoked, ordinary active member, Chairman, Vice Chairman and Platform Admin.
6. Run Supabase security advisors and record actual results/evidence.
7. Present the final production migration for explicit approval before applying it to production.

## Release acceptance tests

- New signup cannot access private data before email verification and approval.
- Verified but pending user cannot access private data or protected RPCs.
- User cannot set their own approval state, platform role or club role using direct REST/RPC calls.
- Only Platform Admin can approve/reject membership and assign/revoke roles.
- Vice Chairman cannot assign roles.
- Invalid role values and duplicate active assignments are rejected by the database.
- A rejected, suspended or revoked user remains denied through direct API calls and an existing session.
- Every approval, rejection, suspension, revocation and role change creates an immutable audit event.
- Anonymous/public access exposes only intentionally published club information.
- No service-role secret is present in repository source or browser assets.

## Current verified status

- Repository /app/index.html is an information placeholder and does not provide a real login or signup form.
- The identity SQL is labelled review-draft-only; its own comments say trusted invitation/activation/suspension/revocation/role assignment/audit writes are not implemented.
- The repository's RLS checklist explicitly says it is not evidence that tests were executed.
- Therefore signup, approval, role assignment, end-to-end authorization and security tests must not be represented as complete until implemented and evidenced.

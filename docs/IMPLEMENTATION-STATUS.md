
# Timau Union FC — Implementation Status

Last updated: 19 October 2026

## Project overview

Timau Union FC is a community-owned football club based in Timau, Meru County, Kenya.

The project has two distinct parts:

1. **Public club website** — accessible without signing in and limited to approved public information.
2. **Private management application** — planned for `/app`, requiring authentication and role-based authorisation.

The public website must not expose private management records or provide a route around the private application's security controls.

## Phase 1: Public website

**Status: Source package prepared for manual upload and review.**

### Included in the source package

- [x] Public homepage and club introduction.
- [x] Fixtures and results placeholders.
- [x] League table placeholder.
- [x] Squad and coaching section.
- [x] Club news placeholders.
- [x] Sponsors and supporters section.
- [x] Club history and achievements.
- [x] Contact section with unconfirmed details withheld.
- [x] Mobile-first responsive layout.
- [x] Accessible mobile navigation.
- [x] Member-access placeholder.
- [x] Setup and hosting documentation.
- [x] Club-inspired red, white and black visual theme, with yellow highlights.
- [x] Club crest asset included as a temporary concept, pending confirmation of the official crest.

### Outstanding verification

- [ ] Confirm all Phase 1 files are committed to the GitHub repository.
- [ ] Review the public content with authorised club officials.
- [ ] Replace the concept crest with the approved official crest, if supplied.
- [ ] Verify all navigation links and asset paths.
- [ ] Test on mobile and desktop devices.
- [ ] Check accessibility, keyboard navigation and supported browsers.
- [ ] Confirm GitHub Pages configuration.
- [ ] Verify the published website URL and deployed version.
- [ ] Confirm that no private records, credentials or sensitive information are exposed.

**Important:** Preparing or manually uploading source files does not, by itself, confirm that the changes are committed, tested or deployed.

### Phase 1 boundaries

This phase covers the public website and a non-functional member-access placeholder only.

The member-access page is not an authentication system. It must not collect passwords, verification codes or other credentials until an approved and secure authentication implementation exists.

The public website must remain usable without signing in. Its only connection to the private application is the clearly labelled **Member login** link.

## Phase 2: Authentication and access design

**Status: Not implemented. Design review and explicit approval required.**

Before implementation, review and approve:

- [ ] Email-invitation-only access, with no public self-registration.
- [ ] Chairman-controlled invitations and role assignment.
- [ ] Vice Chairman's deputy responsibilities and limits.
- [ ] Approved club roles and their individual permissions.
- [ ] Secure sign-in and account recovery.
- [ ] Session creation, expiry and termination.
- [ ] Account suspension and removal.
- [ ] Supabase authentication configuration.
- [ ] Database access policies and Row Level Security (RLS).
- [ ] Tests for unauthorised access and role escalation.

### Role governance

The Chairman is responsible for invitations and role assignment under the approved governance model.

The Vice Chairman acts as the deputy but must not independently assign roles.

No role should receive access merely because a page, navigation item or URL is hidden. Permissions must be enforced by the backend and database policies.

There must be no public self-registration unless the club explicitly approves a change to this requirement.

## Phase 3: Private management application

**Status: Not implemented. Separate scope and approval required.**

Potential modules for a later approved phase include:

- [ ] Members and player records.
- [ ] Fixtures, results and attendance.
- [ ] Training and team management.
- [ ] Club news and content approval.
- [ ] Sponsors and supporter records.
- [ ] Club finances, budgets and expenses.
- [ ] Equipment and other club assets.
- [ ] Reports and activity records.

Before developing each module:

1. Define its purpose and scope.
2. Identify which roles can view, create, edit, approve or delete records.
3. Define data ownership and access boundaries.
4. Specify the database schema and any proposed migrations.
5. Review RLS policies and backend operations.
6. Test permitted and denied actions.
7. Obtain explicit approval before implementation and release.

Sensitive records must remain in the private application and must never be exposed through public website queries or public database views.

## Phase 4: Public content workflow

**Status: Proposed; not implemented or approved.**

Proposed workflow:

1. An authorised contributor submits content.
2. An authorised reviewer checks accuracy and suitability.
3. The Chairman or an explicitly authorised delegate approves publication.
4. Only approved public content is published.
5. Private records remain restricted to authorised users.

Before implementation, confirm who can submit, review, approve, publish, edit and withdraw public content. Approval permissions must be enforced, not merely represented by interface controls.

## Security requirements

These requirements apply throughout the project:

- Never place Supabase service-role keys, private API keys or other secrets in HTML, CSS, client-side JavaScript or public repository files.
- Treat the Supabase publishable/anonymous client key as public configuration only; it must always be backed by correctly configured database policies.
- Do not treat hidden navigation, client-side role checks or obscure URLs as access control.
- Enforce private-data access using authenticated backend operations and appropriately tested Supabase RLS policies.
- Apply least-privilege access: each role receives only the permissions it needs.
- Use public-safe data for the public website.
- Keep private player details, financial records and internal management discussions out of public pages and public responses.
- Obtain appropriate permission before publishing personal information, photographs or sponsor branding.
- Validate user input and handle errors without exposing secrets or sensitive records.
- Test unauthorised access, role escalation and direct requests to protected data.
- Keep authentication and private management changes separate from the static public website.

## Hosting and release policy

- The intended public deployment path is **GitHub `main` → GitHub Pages → the verified club domain or published URL**.
- Do not introduce Vercel deployment configuration or change the approved hosting path without explicit authorisation.
- Do not claim a deployment is live until the published website has been checked.
- Do not apply database migrations or change authentication, database permissions or production data as part of Phase 1.

## Release gates

No Supabase migrations, authentication changes, private management features or deployment changes are authorised by this Phase 1 package.

Every later phase requires:

1. A documented scope and acceptance criteria.
2. Review of proposed database changes before any migration.
3. Explicit approval before implementation.
4. Appropriate access controls and security review.
5. Testing of both authorised and unauthorised actions.
6. Verification of the release and its deployed state.

## Current next steps

1. Confirm the Phase 1 source files are present in the GitHub repository.
2. Review the website locally and verify links, mobile layout and crest assets.
3. Obtain club officials' approval for public-facing content.
4. Configure and verify GitHub Pages using the approved hosting path.
5. Record the actual test and deployment results before marking any outstanding checklist items complete.
6. Keep Phases 2–4 in the design and approval stage until separately authorised.

**Current release decision:** Phase 1 is prepared for review. Implementation, security verification and production deployment remain unconfirmed until the relevant checks have been completed.

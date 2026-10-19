
# Timau Union FC — Implementation Status

Last updated: 19 October 2026

## Project overview

Timau Union FC is a community-owned football club based in Timau, Meru County, Kenya.

The project has two distinct parts:

1. **Public club website** — accessible without signing in and limited to approved public information.
2. **Private management application** — planned for `/app`, requiring authentication and role-based authorisation.

The public website must not expose private management records or provide a route around the private application's security controls.

## Phase 1: Public website

**Status: Published and verified by the project owner.**

Public website:

https://jacqmurithi-ux.github.io/timau-union-fc/

### Included in Phase 1

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
- [x] Live website verification confirmed by the project owner.
- [x] `docs/IMPLEMENTATION-STATUS.md` updated.
- [x] `docs/CREST-MANAGEMENT.md` updated.
- [x] Documentation changes committed to GitHub `main`, as confirmed by the project owner.

### Outstanding Phase 1 actions

- [ ] Obtain formal club-official approval for public-facing content.
- [ ] Obtain and approve the official club crest.
- [ ] Replace the temporary concept crest once approved, if necessary.
- [ ] Record any remaining technical test results not explicitly confirmed.

### Phase 1 release boundaries

The member-access page is a placeholder, not an authentication system. It must not collect passwords, verification codes or other credentials.

The public website must remain accessible without signing in. Its only connection to the private application is the clearly labelled **Member login** link.

No private player details, financial records or internal management discussions may be exposed through public pages.

## Phase 2: Authentication and access design

**Status: Not implemented. Separate review and explicit approval required.**

Before development begins, review and approve:

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

Permissions must be enforced by the backend and database policies, not merely by hiding navigation items or application pages.

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

Before developing any module:

1. Define its purpose and scope.
2. Identify which roles can view, create, edit, approve or delete records.
3. Define data ownership and access boundaries.
4. Specify the database schema and proposed migrations.
5. Review RLS policies and backend operations.
6. Test permitted and denied actions.
7. Obtain explicit approval before implementation and release.

Sensitive records must remain in the private application and must not be exposed through public website queries or public database views.

## Phase 4: Public content workflow

**Status: Proposed; not implemented or approved.**

Proposed workflow:

1. An authorised contributor submits content.
2. An authorised reviewer checks accuracy and suitability.
3. The Chairman or an explicitly authorised delegate approves publication.
4. Only approved public content is published.
5. Private records remain restricted to authorised users.

Before implementation, confirm who can submit, review, approve, publish, edit and withdraw public content. Approval permissions must be enforced rather than represented by interface controls alone.

## Security requirements

These requirements apply throughout the project:

- Never place Supabase service-role keys, private API keys or other secrets in HTML, CSS, client-side JavaScript or public repository files.
- Treat Supabase publishable/anonymous client keys as public configuration only; correctly configured database policies must protect the underlying data.
- Do not treat hidden navigation, client-side role checks or obscure URLs as access control.
- Enforce private-data access through authenticated backend operations and appropriately tested Supabase RLS policies.
- Apply least-privilege access.
- Use public-safe data for the public website.
- Keep private player details, financial records and internal management discussions out of public pages and public responses.
- Obtain appropriate permission before publishing personal information, photographs or sponsor branding.
- Validate user input and handle errors without exposing secrets or sensitive records.
- Test unauthorised access, role escalation and direct requests to protected data.
- Keep authentication and private management changes separate from the static public website.

## Hosting and release policy

- The approved public deployment path is **GitHub `main` → GitHub Pages → published club website**.
- Do not introduce Vercel deployment configuration or change the approved hosting path without explicit authorisation.
- Record deployment as verified only after checking the published website.
- Do not apply database migrations or change authentication, database permissions or production data as part of Phase 1.

## Release gates

The Phase 1 package does not authorise Supabase migrations, authentication changes, private management features or hosting changes.

Every later phase requires:

1. A documented scope and acceptance criteria.
2. Review of proposed database changes before any migration.
3. Explicit approval before implementation.
4. Appropriate access controls and security review.
5. Testing of both authorised and unauthorised actions.
6. Verification of the release and its deployed state.

## Current next steps

1. [x] Publish the Phase 1 website to GitHub Pages.
2. [x] Verify the live website, as confirmed by the project owner.
3. [x] Update the implementation-status documentation.
4. [x] Update the crest-management documentation.
5. [ ] Obtain formal club-official approval for public content.
6. [ ] Approve and integrate the official club crest.
7. [ ] Review and explicitly approve the scope of Phase 2 before beginning authentication work.

## Current release decision

**Phase 1: Published and verified by the project owner.**

Formal approval of public content and the official crest remains outstanding.

**Phases 2–4: Not implemented.** Work on authentication, database changes and private management features must wait for separate review and explicit approval.

No repository changes beyond those confirmed by the project owner are implied by this status document.

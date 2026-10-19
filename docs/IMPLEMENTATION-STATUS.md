
# Timau Union FC — Implementation Status

Last updated: 19 October 2026

## Phase 1: Public website

Status: Source package prepared for manual upload and review.

### Included in this phase

- [x] Public homepage and club introduction.
- [x] Fixtures and results placeholder.
- [x] League table placeholder.
- [x] Squad and coaching section.
- [x] Club news placeholder.
- [x] Sponsors and supporters section.
- [x] Club history and achievements.
- [x] Contact section with unconfirmed details withheld.
- [x] Mobile-first responsive layout.
- [x] Accessible mobile navigation.
- [x] Member-access placeholder.
- [x] Setup and hosting documentation.

### Not yet verified

- [ ] Files committed to GitHub.
- [ ] Website tested on mobile and desktop.
- [ ] All navigation links checked.
- [ ] Accessibility and browser checks completed.
- [ ] GitHub Pages configured.
- [ ] Published website URL verified.
- [ ] Club officials have approved public content.

A source package being prepared does not mean the files have been
uploaded, tested or deployed.

## Phase 2: Authentication and access design

Status: Not implemented.

Before development begins, review and approve:

- Email-invitation-only access.
- Chairman-controlled invitations and role assignment.
- Vice Chairman's deputy permissions.
- The approved club roles and their responsibilities.
- Secure sign-in and account recovery.
- Session management and account removal.
- Supabase Row Level Security and database access policies.

There must be no public self-registration unless the club separately
approves a change to this requirement.

## Phase 3: Private management application

Status: Not implemented.

Potential modules for a separately approved phase:

- Members and player records.
- Fixtures, results and attendance.
- Training and team management.
- Club news and content approval.
- Sponsors and supporter records.
- Club finances, budgets and expenses.
- Equipment and other club assets.
- Reports and activity records.

Before implementation, define each module's authorised roles and
data-access rules. Keep sensitive records out of the public website.

## Phase 4: Public content workflow

Status: Not implemented.

Proposed workflow:

1. An authorised contributor submits content.
2. The appropriate reviewer checks the information.
3. The Chairman or an explicitly authorised delegate approves it.
4. Approved public information is published.
5. Private records remain accessible only to authorised users.

The final approval workflow must be confirmed before implementation.

## Security requirements

- Do not include secret keys in HTML, CSS or JavaScript.
- Do not treat hidden navigation or an obscure URL as access control.
- Do not rely on frontend role checks alone.
- Enforce private-data access through authenticated backend and
  database policies.
- Use public-safe data for the public website.
- Do not expose private player details, financial records or internal
  management discussions.
- Obtain permission before publishing personal details, photographs
  or sponsor branding.

## Release gates

No Supabase migrations, authentication changes, private management
features or deployment changes are authorised by this Phase 1 package.

Each later phase must have a reviewed scope, explicit approval,
appropriate security controls and testing before release.

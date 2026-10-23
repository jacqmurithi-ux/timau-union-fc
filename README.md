# Timau Union FC

Timau Union FC is a community-owned football club based in Timau, Meru County, Kenya. This repository contains the club's mobile-first public website and the evolving private club-management system.

## Project structure and hosting

- The public website uses plain HTML, CSS and JavaScript.
- The intended public hosting target is GitHub Pages from `main`, using the repository's root folder.
- Do not add Vercel configuration unless the hosting decision is explicitly changed.
- Keep public website assets and pages separate from private management data.
- Check the active branch and its implementation status before assuming a feature is implemented or production-ready.

Repository: https://github.com/jacqmurithi-ux/timau-union-fc

## Design and usability

- Club palette: red and white, with black/dark contrast and yellow highlights.
- Mobile-first layouts for volunteers and supporters using phones and limited mobile data.
- Keep navigation clear, layouts readable, and empty states explicit.
- The current crest artwork may be a concept; do not describe it as officially approved until the club confirms it.
- Do not invent club details, fixtures, results, sponsors, players, statistics or contact information.

## Public website

The public website is intended to present club information such as the club story, fixtures and results, league table, squad, news, sponsors, supporters and contact details. Only verified, approved public information should be published. Public pages must never expose private management records, financial information, internal notes or credentials.

## Private management system

Management work is developed separately from the public website. Authentication, invitation workflows, roles, database-backed workspaces and permissions must be verified in the active implementation branch; a hidden page or JavaScript-only role check is not a security boundary.

Security requirements:

- Supabase Row Level Security (RLS) and database functions are the security boundary for database access.
- Preserve the existing role model and permission boundaries when adding features.
- Keep internal record access distinct from approval and public publication permissions.
- Do not expose service-role keys, private records or internal notes in browser code or public files.
- Do not change database permissions or roles as a side effect of unrelated UI work.
- Review and test database migrations before applying them to production.
- Do not seed invented or sample records into production.

## Social media stats tracking — implementation scope

The Social stats feature is intended for manual entry by authorized Media Team members; it does not use social-platform APIs.

The planned capability includes:

- Posts recorded by platform, publication date, title, post type, optional URL, sponsor and fixture.
- Editable post metrics: views, reach, likes, comments, shares, saves and link clicks.
- Monthly follower counts and follower gains by platform.
- Internal monthly reporting, filters, month-to-month comparisons, a simple chart, top posts and CSV export.
- A read-only sponsor view limited to that sponsor's tagged posts and the club's monthly summary.
- A reminder for posts older than seven days that still have zero recorded views.
- Clear empty states, including “No posts recorded yet,” rather than fabricated data.

### Intended access boundaries

- Media Team, Admin and Chairman: create and update social posts and statistics, subject to the approved role mapping.
- Secretary, Treasurer, Sponsor Lead, Team Manager and Coach: read-only access.
- Sponsors: read only their own sponsor-tagged posts and the permitted monthly summary.
- Public/anonymous visitors: no access to private social-statistics records.

These are requirements, not proof that the feature or its database policies have already been deployed. Confirm the migration, RLS policies, role resolution and portal UI in the active branch before treating the feature as available. Sponsor-facing queries must not reveal other sponsors' post records or internal notes.

If an existing social-media calendar is present, published calendar items may link to their post records. Do not create a new calendar as part of this feature.

## Database and migration practice

- Use additive, narrowly scoped migrations where possible.
- Confirm the actual names and key relationships of existing `sponsors`, `fixtures`, user-role and membership structures before referencing them.
- Use foreign keys and constraints to protect data integrity.
- Enable RLS and test access as each relevant role, including anonymous users and sponsors.
- Never assume a front-end filter provides data isolation.
- Keep production free of sample posts, followers and engagement figures.

## Local preview and verification

1. Clone or download the repository and keep its directory structure intact.
2. Open `index.html` or serve the repository with a simple static HTTP server.
3. Check the public site on mobile and desktop.
4. For management features, use the project's approved test environment and test accounts.
5. Verify role access, empty states, data validation, responsive layouts and browser-console errors.
6. Verify that private management pages and data are not exposed through public routes or assets.
7. Before release, review the changed-file list and migration, run available syntax/tests, and verify the deployed GitHub Pages site after changes are merged to `main`.

## Pre-publication checks

- Confirm the club-approved crest, contact details, official social links and public club information.
- Verify fixtures, results, league table, squad details and sponsor acknowledgements before publishing.
- Obtain permission before publishing identifiable player/supporter photographs or personal information.
- Do not announce a deployment as complete until the published site has been checked.

---

**Project rule:** Keep changes scoped, mobile-first and security-conscious. Preserve existing pages, roles, permissions and hosting decisions. Document unimplemented or proposed features as such; do not imply they are live until verified.


# Timau Union FC

A mobile-first public website for Timau Union FC, a community-owned
football club based in Timau, Meru County, Kenya.

## Phase 1 files

- `index.html` — public club website.
- `styles.css` — responsive styling.
- `script.js` — mobile navigation and footer year.
- `app/index.html` — non-functional member-access placeholder.
- `docs/IMPLEMENTATION-STATUS.md` — current scope and future approval gates.

## Current features

The public website includes:

- Club introduction and history.
- Fixtures and results section.
- League standings section.
- Squad and coaching information section.
- Club news section.
- Sponsors and supporters section.
- Club contact section.
- Member login link to the placeholder page.
- Responsive mobile navigation.

Information that has not been confirmed is shown as a placeholder.

## Preview locally

Keep the folder structure intact. Open `index.html` in a modern browser.
For local development, you may also use a simple static HTTP server.

## GitHub Pages hosting

1. Push the approved files to the repository's `main` branch.
2. Open the repository on GitHub.
3. Go to **Settings → Pages**.
4. Under the build and deployment section, select **Deploy from a branch**.
5. Select the `main` branch and `/ (root)` folder.
6. Save and wait for GitHub Pages to finish publishing.

The expected project URL, once configured, is:

https://jacqmurithi-ux.github.io/timau-union-fc/

This URL is an expectation, not confirmation that deployment has occurred.
Check the Pages settings for the actual published URL.

## Important security boundaries

This phase is a static public website.

- The member-access page is only a placeholder.
- No password collection or authentication is implemented.
- No Supabase client or credentials are included.
- No database tables, migrations, policies or storage buckets are created.
- No role-based access control is implemented.
- A hidden page, HTML file or JavaScript check is not a security boundary.
- Do not put private player records, financial data, credentials or
  confidential management information in public files.

Future management features must use approved authentication, server-side
or database-enforced permissions, and appropriate Supabase Row Level
Security policies.

## Before publishing

Confirm the club's approved name, logo, contact details, sponsors, squad
information and official social-media links. Do not publish unverified
contact details or photos without permission.

## Out of scope for Phase 1

- Supabase authentication and invitation workflows.
- User roles and management permissions.
- Fixtures administration and database integration.
- Player registration and private player records.
- Financial management, sponsor payments or club accounting.
- News publishing and approval workflows.
- File uploads and private storage.
- Automated deployment configuration beyond GitHub Pages settings.

These items require a separate implementation plan and approval.

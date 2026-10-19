
# Timau Union FC

A mobile-first public website for Timau Union FC, a community-owned football club based in Timau, Meru County, Kenya.

The Phase 1 public design uses the club's red, white and black palette with bright yellow highlights, a club crest concept, a prominent match-centre area and clear sections for club news, the squad and supporters.

The visual direction is inspired by polished modern football-club websites, without copying another club's identity.

## Phase 1 files

- `index.html` — public club website.
- `styles.css` — mobile-first responsive styling.
- `script.js` — mobile navigation and footer year.
- `assets/club-crest.svg` — temporary crest concept; replace it with the club-approved crest before official publication.
- `app/index.html` — non-functional member-access placeholder.
- `docs/CREST-MANAGEMENT.md` — proposed secure workflow for changing the club crest in a future approved backend phase.
- `docs/IMPLEMENTATION-STATUS.md` — current scope and future approval gates.

Keep the folder structure intact when uploading or previewing the website.

## Current public website sections

The public website includes:

- Club introduction and history.
- Fixtures and results / match centre.
- League standings.
- Squad and coaching information.
- Club news.
- Sponsors and supporters.
- Club contact information.
- Member login link to the placeholder page.
- Responsive mobile navigation.
- Mobile-first layouts designed for visitors using phones.

Unconfirmed fixtures, results, standings, squad details, sponsors and contact information must remain clearly marked as placeholders until verified. Do not invent official club information.

## Club design direction

The approved design direction is:

- **Primary colours:** red and white.
- **Contrast colours:** black and dark backgrounds.
- **Highlight colour:** bright yellow for selected accents and calls to action.
- **Branding:** use the club crest in the website header and browser icon where supported.
- **Homepage message:** "Our club. Our community. Our future."
- **Presentation:** a strong football-club identity, prominent match centre, clear news sections and visible supporter and sponsor recognition.
- **Usability:** responsive layouts, simple navigation, readable text and consideration for visitors with limited mobile data.

The current crest artwork is a concept only. It must not be represented as the club's officially approved crest until the club confirms it.

## Preview locally

1. Download or clone the project.
2. Keep the folder structure intact.
3. Open `index.html` in a modern web browser.
4. Check the website on both mobile and desktop screen sizes.
5. Confirm that the crest, stylesheet, JavaScript and navigation work correctly.

For local development, you may also use a simple static HTTP server.

## GitHub Pages hosting

The intended hosting method is GitHub Pages using the repository's `main` branch. Do not add Vercel configuration unless the project hosting decision is explicitly changed.

1. Upload or push the approved files to the repository's `main` branch.
2. Open the repository on GitHub.
3. Go to **Settings → Pages**.
4. Under **Build and deployment**, select **Deploy from a branch**.
5. Select the `main` branch and `/ (root)` folder.
6. Save the configuration.
7. Wait for GitHub Pages to finish publishing.
8. Open the published URL and verify the website.

Repository:

https://github.com/jacqmurithi-ux/timau-union-fc

Expected project URL after Pages is configured:

https://jacqmurithi-ux.github.io/timau-union-fc/

This is an expected URL, not confirmation that deployment has occurred. Check the repository's Pages settings for the actual published URL and verify the live site after publishing.

## Important security boundaries

Phase 1 is a static public website.

- The member-access page is only a placeholder.
- No password collection or authentication is implemented.
- No Supabase client or credentials are included.
- No database tables, migrations, policies or storage buckets are created.
- No role-based access control is implemented.
- A hidden page, HTML file or JavaScript check is not a security boundary.
- Do not put private player records, financial data, credentials or confidential management information in public files.
- Do not include private management-system data in public JavaScript or HTML.
- Do not treat the member login link as proof of identity or authorization.

Future management features must use the approved authentication and invitation design, server-side or database-enforced permissions, and appropriate Supabase Row Level Security (RLS) policies.

The public website and private management system must remain separate. The public website must not expose private management records.

## Future crest management

The current SVG crest is a temporary concept, not confirmation of the official club crest.

The documented crest-management workflow is a future specification only. There is no active crest-upload interface or working backend in Phase 1.

A separately approved future implementation should include:

- Permission checks so only authorized officials can change the crest.
- File type, size and content validation.
- A preview before publication.
- A controlled publish action.
- Safe replacement and rollback to a previously approved crest.
- Secure storage and appropriate access policies.
- Public access only to the currently published crest asset.
- No public exposure of credentials, private storage paths or management records.

Do not implement this backend until its design and security approach have been reviewed and approved.

## Before publishing

Confirm the following with the club:

- Official club name and approved crest.
- Contact phone number and email address.
- Official social-media links.
- Fixtures, results and league standings.
- Squad list and coaching information.
- Sponsors and supporter acknowledgements.
- Club history and official news.

Obtain permission before publishing identifiable player or supporter photographs and personal information.

Keep unknown details clearly marked as placeholders until confirmation is received.

## Out of scope for Phase 1

The following require a separate implementation plan and explicit approval:

- Supabase authentication and invitation workflows.
- User roles and management permissions.
- Fixtures administration and database integration.
- Player registration and private player records.
- Financial management, sponsor payments or club accounting.
- News publishing and approval workflows.
- Crest upload and publishing backend.
- Other file uploads and private storage.
- Database tables, migrations, RLS policies or storage buckets.
- Automated deployment configuration beyond GitHub Pages settings.
- Management dashboards and administrative workflows.

## Phase 1 completion checklist

Before treating the public website as ready for official launch:

- [ ] Confirm the approved club crest.
- [ ] Verify all club information displayed publicly.
- [ ] Check that no unverified contact details or photographs are published.
- [ ] Test mobile navigation.
- [ ] Test the website on mobile and desktop.
- [ ] Check all internal links and asset paths.
- [ ] Confirm the member-access page is clearly identified as a placeholder.
- [ ] Confirm no private data or credentials are present in public files.
- [ ] Configure GitHub Pages from `main` and `/ (root)`.
- [ ] Verify the published website and actual URL.
- [ ] Obtain club approval before announcing the website as official.

---

**Project rule:** Keep Phase 1 focused on the public club website. Do not implement backend features, change approved security boundaries or expand the project scope without separate approval.

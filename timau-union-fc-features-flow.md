# Timau Union FC — Features and User Flows
**Status:** Design proposal only — do not implement until the club approves the design.

## 1. Product structure: two separate parts

### A. Public club website — no login
A professional football-club website for supporters, players, partners and the community. Public visitors do not need an account.

### B. Management system — `/app`
A separate, login-required system for authorized club operations. Every feature must be available only to permitted roles. Supabase Row Level Security (RLS) and server-side authorization must enforce permissions; hiding a menu item is not sufficient.

The only intended route from the public website into the management system is the **Member login** button. Public pages must not expose management features, private records or internal data.

## 2. Public website navigation

Header:
- Club crest and Timau Union FC name
- Home
- Fixtures and Results
- Table
- Squad
- News
- Sponsors
- The Club
- Contact
- **Member login** button

### Home
- Hero section featuring the next match and a countdown, when confirmed match data is available
- Latest result
- Short league-table preview
- Latest approved news
- Photo gallery using approved images
- Sponsor strip showing approved sponsors
- Supporter contact prompt
- Footer with approved social links and contact details

### Fixtures and Results
- Upcoming fixtures and completed results
- Competition filter
- Only publish confirmed match details and results

### Table
- League-table view using a verified source or confirmed data
- Clearly identify the competition and season
- Never invent standings or statistics

### Squad
- Approved player profiles only
- Public fields: name, position, squad number and approved photo
- No private player contacts, welfare notes, identity documents or other sensitive information

### News
- Approved club announcements, match reports and other public updates
- Drafts remain private until approved

### Sponsors
- Approved sponsors and approved logos/links only
- No sponsor is displayed as confirmed before approval

### The Club
- Club history and ambitions
- Approved list of club officials
- Public contact details approved for publication

### Contact
- Approved public contact channels and social links
- Do not expose personal phone numbers or private contact records without explicit authorization to publish them

### Club Store
- A public Club Store page is planned for **Phase 5**, not the initial release.
- Product listings, stock handling, orders and payment verification will be designed and approved before implementation.
- Payment must not be represented as verified automatically if it requires manual M-Pesa confirmation.

## 3. Public content approval workflow

1. An authorized media/content user creates or edits a draft.
2. The draft remains private and is not shown on public pages.
3. The Chairman reviews the proposed public content.
4. The Chairman approves or rejects it.
5. Only approved content is published.
6. Changes to published content return to draft/review status where appropriate, with an audit trail.

Public pages must read only from purpose-built, public-safe views or equivalent restricted data access. They must never query private management tables directly. No finances, welfare information, private contacts, internal notes or other management-only data may appear publicly.

## 4. Management system (`/app`)

- Login required.
- Role- and permission-based navigation.
- Each action checked by backend authorization and Supabase RLS/RPC policies.
- Unauthorized requests must fail securely even if a user manually opens a URL or calls an API.
- Sensitive changes and approvals should be recorded in an audit log.
- Do not grant permissions based solely on client-side role labels or hidden buttons.

Detailed roles and permissions must be finalized in the approved data model and screen specifications before implementation.

## 5. Opening balance — dual confirmation

1. The Treasurer prepares the proposed opening balance and supporting details.
2. The proposal remains **Pending confirmation**.
3. The Treasurer and Chairman must each confirm it.
4. Neither person may satisfy both confirmations alone; the two confirmations must be distinct and attributable.
5. Until both confirmations are recorded, the opening balance is excluded from official totals and reports.
6. Once both confirmations are complete, the opening balance is locked and included in the relevant totals.
7. Any subsequent correction must be a separate, logged adjustment with a reason, actor and timestamp. Do not silently edit the confirmed opening balance.
8. The exact treatment of conflicts, rejected proposals and correction approvals must be specified before implementation.

## 6. Visual direction and usability

Use general inspiration from the information hierarchy of professional football-club websites, including Arsenal's broad layout approach, without copying its crest, logo, photography, text, code or exact color scheme.

Suggested structure:
- Slim top bar and clear club identity
- Match strip for the next fixture and latest result
- Strong hero area
- News grid
- Fixtures and results with competition filtering
- League-table preview
- Approved squad cards
- Sponsors and gallery
- Club history and footer

Design principles:
- Professional, fast and mobile-first
- Use Timau Union FC's own crest and colors when supplied; use placeholders until then
- Strong typography, generous spacing and large touch targets
- Optimize images and loading for mobile data connections
- Accessible contrast, readable text and clear navigation
- Avoid fabricated players, sponsors, results, standings, statistics or club history
- Publish only information that has been approved for public use

## 7. Scope boundary and approval gate

This document defines the proposed experience and workflows only. It does **not** authorize writing application code, creating database objects, changing Supabase policies, or deploying anything.

**Next step:** Review and approve or request changes to this design. Implementation should begin only after explicit approval.

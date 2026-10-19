Timau Union FC — Features and User Flows

Status: Design approved — implementation on hold
Project: Timau Union FC
Repository: "jacqmurithi-ux/timau-union-fc"
Public hosting: GitHub Pages from "main"
Backend design: Supabase Auth, PostgreSQL and Row Level Security (RLS)

1. Product structure: two separate parts

A. Public club website — no login

A professional football-club website for supporters, players, partners and the community. Public visitors do not need an account.

The public website displays only verified information and content approved for publication.

B. Management system — "/app"

A separate, login-required system for authorized club operations.

- Access is invitation-only.
- No public self-registration.
- Players do not have login accounts.
- Authorized officials maintain player records.
- Every feature is restricted by role and specific permissions.
- Supabase RLS and trusted backend authorization enforce access.
- Hiding a menu item or checking a role in JavaScript is not a security boundary.

The only intended route from the public website into management is the Member Login button. Public pages must not expose management features, private records or internal data.

The current static website and any login placeholder do not provide real authentication.

2. Public website navigation

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
- Member Login

The Club Store is planned for Phase 5 and is not part of the initial release.

Home

- Hero section featuring the next match and countdown, when confirmed match data is available.
- Latest verified result.
- Short league-table preview.
- Latest approved news.
- Photo gallery using approved images.
- Sponsor strip showing approved sponsors.
- Supporter contact prompt.
- Footer with approved social links and contact details.

Fixtures and Results

- Upcoming fixtures and completed results.
- Competition filter.
- Only publish confirmed match details and results.

Table

- League-table view using a verified source or confirmed data.
- Clearly identify the competition and season.
- Never invent standings or statistics.

Squad

- Approved player profiles only.
- Public fields: name, position, squad number and approved photograph.
- No private player contacts, welfare notes, identity documents or other sensitive information.
- Public player information must be reviewed and approved before publication.

Players do not log in to maintain their profiles. Authorized club officials maintain the underlying records.

News

- Approved club announcements, match reports, interviews, stories and other public updates.
- Drafts and content awaiting approval remain private.
- Only approved content appears on public pages.

Sponsors

- Approved sponsors and approved logos or links only.
- No sponsor is displayed as confirmed before approval.

The Club

- Verified club history and ambitions.
- Approved list of club officials.
- Public contact details approved for publication.

Contact

- Approved public contact channels and social links.
- Do not expose personal phone numbers or private contact records without explicit authorization to publish them.

3. Public content approval workflow

The club's publication workflow supports both the Chairman's final approval authority and the approved deputy arrangement for the Vice Chairman.

1. An authorized content creator, including a Media Team member, creates or edits a draft.
2. The draft remains private and is not shown on public pages.
3. The draft is submitted for review.
4. The Chairman reviews and approves or rejects the proposed content.
5. When the Chairman is unavailable, the Vice Chairman may approve and publish content under the explicitly delegated deputy publication authority.
6. The system records the approver, publication action and timestamp.
7. Only approved content is published.
8. Changes to published content return to draft or review status where appropriate.
9. Withdrawal, correction and republication follow an authorized workflow and are recorded.

The Vice Chairman's delegated publication authority does not include independent role assignment or automatic access to financial or confidential records.

The Media Team may prepare and edit assigned content but cannot bypass the approval workflow by changing a status through a direct API request.

The implementation must define how the Chairman's unavailability and the Vice Chairman's delegated authority are verified.

Public data boundary

Public pages must read only from purpose-built public-safe views or equivalent restricted data access.

They must never query private management tables directly in a way that exposes confidential records. Finances, welfare information, private contacts, internal notes and other management-only data must not appear publicly.

4. Management system ("/app")

Entry and access

1. An invited official opens "/app".
2. The official signs in using the approved authentication process.
3. The system verifies identity, active club membership and assigned permissions.
4. The dashboard and navigation show only the areas the official is authorized to access.
5. Each protected request is independently checked by the backend and database policies.
6. Unauthorized or revoked users are denied access.

No public registration or player login is provided.

Management areas

- Dashboard
- Data Centre
- Reports
- Players
- Fixtures and Results
- Training and Attendance
- News and Media
- Documents
- Finance, restricted to authorized officials
- Club Store management, planned for Phase 5
- User and Role Management, restricted to authorized role managers
- Audit History, restricted to authorized officials

Not all sections need to appear for every role. The final capability-to-role mapping must be followed by the implementation.

5. Role and permission boundaries

Role| Intended responsibilities
Chairman| Overall club oversight, role assignments, access management and final publication approval
Vice Chairman| Deputy responsibilities and delegated operational duties; may approve and publish news when the Chairman is unavailable under the approved delegation
Secretary| Authorized player registration, official records, documents and club administration
Team Manager| Team operations, permitted player records, fixtures, results and attendance
Treasurer| Financial records, financial reports and authorized financial administration
Coach| Authorized squad information, training, attendance and match preparation
Sponsor Lead| Sponsor records and sponsor-related activity
Media Team| Drafting and editing assigned news, stories, photographs and match reports
Player| No login account; records maintained by authorized officials
Supporter| Public website access only

Role-management rules

- The Chairman may assign official roles.
- Another role manager may do so only if explicitly authorized.
- The Vice Chairman cannot independently assign or elevate official roles.
- The Secretary, Team Manager and other specifically authorized officials may maintain player records within their permitted scope.
- The Media Team does not automatically receive access to private player information, welfare records, finances, confidential documents or role management.
- Financial information is restricted to the Treasurer and any other explicitly authorized officials.
- Multiple roles must not unintentionally bypass restrictions.

The backend must enforce these boundaries even when someone manually opens a URL or sends a direct API request.

6. Data Centre — central records management

Purpose

The Data Centre is the central records-management area for all authorized officials, not a Chairman-only or administrator-only area.

Officials can access the sections, records, fields and actions permitted by their roles and explicit authorizations.

Player register

- Maintain player registration and approved profile information.
- Support permitted corrections and record updates.
- Identify incomplete registrations and possible duplicates.
- Maintain a history of important changes.
- Separate internal player records from approved public squad profiles.

Players do not self-register and do not receive login accounts.

Officials and roles

- Maintain the official directory and assigned roles.
- View invitation and access status where authorized.
- Restrict role assignment to the Chairman or explicitly authorized role managers.
- Record role changes and access revocations.

Fixtures and Results

- Maintain schedules, opponents, venues and results.
- Record approved match reports.
- Validate required information.
- Track material changes.

Only verified information should be published publicly.

Training and Attendance

- Record training sessions and attendance.
- Maintain match attendance and participation information where collected.
- Restrict access to authorized team and operational officials.
- Publish only information approved for public release.

Documents

- Organize club documents, forms, minutes, policies and other approved categories.
- Restrict confidential documents to authorized roles.
- Validate file uploads and access permissions.
- Separate public documents from private management files.

News and Media

- Store drafts, stories, match reports, photographs and publication status.
- Give the Media Team access within its assigned scope.
- Track review, approval, publication and withdrawal.
- Keep unpublished content private.

Data quality and exports

- Identify missing required fields, potential duplicates and inconsistent records.
- Allow corrections only to authorized officials.
- Provide controlled exports and downloads.
- Apply the same permissions to exports as to the underlying records.
- Avoid including unnecessary personal or confidential information.

7. Reports

The Reports area provides role-scoped reports, not universal access to all club data.

Planned report categories

Player registration

- Registration totals.
- Squad summaries.
- Registration completeness.

Training and attendance

- Training sessions.
- Attendance and participation summaries.
- Permitted operational comparisons.

Fixtures and Results

- Upcoming fixtures and completed results.
- Authorized match summaries and match reports.

Media activity

- Drafts awaiting review.
- Approval and publication status.
- News and match-report activity.

Financial reports

- Income, expenditure, balances and other authorized financial information.
- Access restricted to the Treasurer and any specifically authorized financial officials.

Data quality

- Missing fields.
- Potential duplicates.
- Unresolved data-quality issues within the viewer's permissions.

Club Store reports — Phase 5

- Orders and fulfilment summaries.
- Payment status and reconciliation for designated officials.
- Restricted customer information and payment records.

Report flow

1. The official selects an authorized report.
2. The backend validates the report type, record scope, requested fields and filters.
3. Only permitted data is returned.
4. Printing and downloading apply the same restrictions.
5. Sensitive exports are recorded where appropriate.

The Reports page must never provide access to records the official cannot otherwise view.

8. Opening balance — dual confirmation

The opening balance workflow must preserve separation of duties.

1. The Treasurer prepares the proposed opening balance and supporting details.
2. The proposal remains Pending confirmation.
3. The Treasurer and Chairman must each provide a distinct confirmation.
4. One person cannot satisfy both confirmation requirements.
5. Until both confirmations are recorded, the opening balance is excluded from official totals and reports.
6. Once both confirmations are complete, the opening balance is locked and included in the relevant totals.
7. A later correction must be a separate, logged adjustment with a reason, actor and timestamp.
8. The confirmed opening balance must not be silently overwritten.
9. Conflicts, rejection and correction-approval procedures must be specified before implementation.

Backend authorization must enforce the distinct confirmations. The interface alone cannot guarantee this separation of duties.

9. Club Store — Phase 5

The Club Store is planned for a later phase and is not part of the initial public website release.

Planned public features

- Club jerseys, kits and approved merchandise.
- Product photographs, descriptions and prices.
- Available sizes and stock status, where supported.
- Order placement and clear collection or delivery instructions.
- Approved payment options.

M-Pesa and cash on collection may be considered, but payment arrangements must be confirmed before the store is launched.

Planned customer order flow

1. Visitor browses the product catalogue.
2. Visitor selects a product, size and quantity.
3. The system validates availability and price.
4. Customer supplies the minimum information required to fulfil the order.
5. The order is recorded through an approved secure workflow.
6. Payment remains pending until verified.
7. Authorized officials process the order and update fulfilment status.
8. The customer receives appropriate order-status information.

A customer-submitted screenshot or browser redirect is not sufficient proof of payment. Manual M-Pesa confirmation must be explicitly recorded as manual verification, and automated payment verification must rely on a trusted provider confirmation.

Store management permissions

- Order management: explicitly authorized store/order officials.
- Payment verification and financial reconciliation: Treasurer or another explicitly authorized financial official.
- Product and stock management: designated officials, with their permissions approved before implementation.
- Media Team: may prepare promotional content but has no automatic access to customer orders or payment records.
- Public visitors: access approved product information only; any future customer order-tracking feature must prevent access to other customers' orders.

Do not store M-Pesa PINs, passwords or unnecessary payment credentials. Protect customer contact details, order records, payment references and internal notes.

No Club Store database, payment integration or transaction-processing code is authorized by this document.

10. Documents, uploads and privacy

- Public and private files must be separated.
- Only approved material may be publicly accessible.
- File type, size and access must be validated.
- Direct file URLs must not bypass permissions.
- Do not publish identity documents, private phone numbers, welfare notes or internal financial records.
- Obtain appropriate authorization before publishing identifiable player or supporter photographs.

11. Visual direction and usability

Use general inspiration from the information hierarchy of professional football-club websites, including Arsenal's broad layout approach, without copying its crest, logo, photography, text, code or exact colour scheme.

Suggested structure:

- Slim top bar and clear club identity.
- Match strip for the next fixture and latest result.
- Strong hero area.
- News grid.
- Fixtures and results with competition filtering.
- League-table preview.
- Approved squad cards.
- Sponsors and gallery.
- Club history and footer.

Design principles

- Professional, fast and mobile-first.
- Use Timau Union FC's own approved crest and colours; use placeholders until confirmed.
- Strong typography, generous spacing and large touch targets.
- Optimize images and loading for mobile data connections.
- Accessible contrast, readable text and clear navigation.
- Avoid fabricated players, sponsors, results, standings, statistics or club history.
- Publish only information approved for public use.

12. Security and error handling

- Anonymous requests for private data must be denied.
- Authenticated users without active membership must be denied private access.
- Unauthorized record access and cross-club requests must fail securely.
- Revoked officials must lose access to protected operations.
- Unauthorized role changes must be rejected.
- Media Team publication attempts without approval must be rejected.
- The Vice Chairman's delegated publication permission must not grant role-management powers.
- Reports and exports must not expose restricted information.
- Unauthorized access to Club Store orders or payment records must be denied.
- Unverified payments must not be treated as paid.
- Invalid or oversized uploads must be rejected.
- Important actions must be attributable to the responsible official.
- Missing or unverifiable permissions must result in denial.

Security tests must include direct API requests, not only browser navigation and button visibility.

13. Scope boundary and approval gate

This document records the approved design. It does not authorize implementation.

The following remain on hold until separately authorized:

- Authentication and invitation code.
- Role-management and permission implementation.
- Database tables, migrations or SQL changes.
- Supabase RLS policy or privilege changes.
- Supabase configuration changes.
- Private document storage and upload implementation.
- Opening balance workflow implementation.
- Club Store order processing or payment integration.
- Management-system deployment or production data changes.

Before implementation, the team must review the detailed permission matrix, proposed data model, RLS policies, trusted operations, and security test plan. Database migrations and SQL/RLS changes must be presented for review before execution.

Project rule: The design is approved, but implementation remains on hold. The public website and private management system must remain separate, with backend-enforced permissions protecting all private records and operations.

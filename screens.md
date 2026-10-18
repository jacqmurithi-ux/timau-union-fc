Timau Union FC — Screen & Navigation Design (Draft)
Status: Wireframe specification only; no application code.
Visual direction
Mobile-first and professional for community football operations.
Neutral palette with green accent proposed; club approves final colors.
Use a placeholder crest until an approved asset is supplied.
High contrast, large touch targets and clear loading/error/empty states.
KSh amounts and Africa/Nairobi date/time display.
Stack records on mobile; use tables on larger screens where useful.
Print layouts hide navigation and exclude unauthorized fields.
Navigation
Suggested mobile navigation: Home · Fixtures · Squad · Updates · More. More contains authorized modules such as Finance, Training, Transport, Welfare, Sponsors, Reports and Club Settings. Hidden navigation is not an authorization control.
Screens
Sign-in/invitation: email sign-in, invite validation, expired/revoked recovery and clear explanation that leadership assigns roles.
Role-aware home: greeting, role, next fixture, availability prompt, pending tasks, latest approved announcement and finance summary only for authorized users. No invented totals.
Fixtures: upcoming/past fixtures, date, kickoff, opponent, competition, venue and status; detail view for availability, transport readiness, match-day checklist and result/report. Design T-7, T-3 and T+1 alerts. Mark unconfirmed facts clearly.
Squad/availability: operational player list, individual availability and selection state restricted to authorized staff. Players see their own information and permitted team details.
Training/attendance: sessions, attendance and authorized coaching notes; no welfare details in general coaching screens.
Transport: fixture-linked needs and confirmations. Distinguish requested, coordinated, confirmed and unresolved. Separate cost estimate, pledge, approval and payment. T-3 review highlights unresolved needs without implying funding exists.
Finance: categorized income/expenses, approved position, evidence and audit trail. Distinguish pledged, received, pending and approved. Opening balance remains pending until approval. Restrict records to authorized roles.
Approval queue: proposer, type, amount where applicable, evidence and submission date; confirm approve/reject actions and capture reasons.
Welfare: restricted list/detail, minimal sensitive data in list rows/notifications, no public indexing, broad export disabled by default.
Sponsors/well-wishers: support type, pledge, amount received, restrictions and acknowledgement. Publish names/logos only with permission and approval; do not promise unapproved bonuses.
Media/announcements: draft → preview → approval → publish/unpublish; public page shows published content only.
Club management: invite by email, assign/revoke roles, deactivate access and review invitations. Log role changes; no self-assignment.
Reports: date-filtered role-scoped reports, printable with club name, period, generated time and state labels. No private welfare details in general reports.
Accessibility and interaction
Short forms with related fields grouped.
Confirm irreversible/high-impact actions.
Plain-language success/errors and preserve values after recoverable validation errors.
Label inputs and show keyboard focus.
Never rely on color alone for status.
Design loading, offline/network and permission-denied states.

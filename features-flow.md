Timau Union FC — Product Features & Flows (Design Draft)
Status: Design only; do not implement until the club approves.
Club: Timau Union FC, Timau, Meru County, Kenya.
Platform: Single-club mobile-first web app; GitHub Pages + Supabase.
Locale: KSh; Africa/Nairobi timezone.
Goals
Coordinate football operations and club administration in one auditable system.
Improve player availability and transport coordination before fixtures.
Record income, expenses and opening balances transparently.
Track sponsors and well-wisher support without promising unapproved payments.
Publish approved public information while protecting player, welfare and financial data.
Provide printable reports.
Roles and intended access
Chairman: club administration, invitations, role assignment and controlled approvals.
Vice Chairman: delegated leadership and operational oversight.
Team Manager: fixtures, squad availability and transport coordination.
Treasurer: finance records, receipts, expenses and financial reports.
Secretary: club records, meetings and administrative reports.
Coaches/technical staff: training, squad and football operations.
Players: own profile, availability, training and permitted fixture details.
Welfare officer: restricted welfare workflow and minimum necessary information.
Media: approved public content, fixtures/results and announcements.
Sponsors: only information explicitly shared with them.
Public: published club profile, approved fixtures/results and announcements.
The Chairman assigns roles after invitations. Job titles must not silently grant permissions. Supabase must enforce access; hiding a menu item is not security.
Proposed modules
Role-aware dashboard.
Club profile, invitations, membership and roles.
Fixtures, results and match reports.
Squad and player availability.
Training and attendance.
Fixture-linked transport coordination.
Finance: income, expenses, receipts and opening balance.
Approvals and audit trail.
Restricted welfare.
Sponsors and well-wisher support.
Media, announcements and public page.
Permission-filtered printable reports.
Invitation flow
flowchart TD
 A[Chairman enters email] --> B[Send invitation]
 B --> C[Invitee signs in]
 C --> D[Validate invitation]
 D --> E[Chairman assigns role]
 E --> F[Role-scoped access]
 D -->|Invalid or expired| G[Safe error and re-invite]
An invitation alone must not grant a privileged role. Users cannot assign roles to themselves.
Fixture and transport readiness
flowchart TD
 A[Confirm fixture] --> B[T-7 days]
 B --> C[Request player availability]
 B --> D[Review transport needs]
 C --> E[Squad readiness]
 D --> F[Transport status]
 E --> G[T-3 readiness review]
 F --> G
 G --> H[Match-day checklist]
 H --> I[Record result and report]
Proposed reminders: T-7, T-3 and T+1. T-3 highlights unresolved transport needs. Confirm channels and scheduling before implementation.
Finance and opening-balance lock
flowchart TD
 A[Authorized user submits transaction] --> B[Validate amount, date, category and evidence]
 B --> C[Pending review]
 C --> D{Authorized approver?}
 D -->|No| E[Reject and log]
 D -->|Yes| F[Approve or reject with reason]
 F --> G[Audit decision]
 G --> H[Update approved summary]
Opening balances remain pending and excluded from approved totals until approved. Distinguish pledged, received, pending, approved and rejected amounts. Corrections require a reason and audit trail.
Privacy
Explain collection purposes and access; obtain consent where required.
Collect only data needed for club operations.
Keep welfare notes, personal contacts and internal finance off public pages.
Publish content only through an authorized workflow.
Define retention and data-rights request procedures.
Address Kenya Data Protection Act and safeguarding requirements before launch.
Never expose private details through public endpoints or static payloads.
Club decisions required
Approval matrix/thresholds; editable player fields; transport support states; sponsor login versus public updates; consent and retention wording; welfare escalation policy; verified Betika Cup dates/rules. Do not invent missing facts.

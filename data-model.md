Timau Union FC — Conceptual Data Model (Design Draft)
Design only. This is not SQL and not a migration.
Principles
One club per deployment.
Supabase is the source of truth for identity and authorization.
Represent money as integer KSh or a chosen exact numeric type, never floating point.
Use Africa/Nairobi for club-facing scheduling.
Enforce constraints and authorization server-side.
Audit sensitive changes and approval decisions.
Separate proposed, pending, approved, rejected and corrected/voided financial states.
Never expose private records directly to public pages.
Proposed entities
Entity
Purpose
club_profile
Club name, location, approved crest/media and public contact settings
user_profiles
Authenticated identity and minimal profile fields
invitations
Invitee email, inviter, expiry, accepted/revoked state
role_assignments
User, role, assigner, validity and status
consent_records
Notice version, purpose, decision, timestamp and withdrawal
players
Player profile, linked user if applicable, status and approved football fields
player_availability
Player, fixture/session, response and timestamp
fixtures
Opponent, competition, venue, kickoff, status and confirmation source
squad_selections
Fixture, player, selection state and editor
training_sessions
Time, location, status and coach
attendance
Person, session/fixture, status and recorder
transport_plans
Fixture, needs, estimated/approved cost and status
financial_accounts
Club-defined categories, not personal bank credentials
financial_transactions
Amount, direction, category, date, evidence and state
opening_balance_requests
Proposed amount, evidence, proposer, reviewer, decision and reason
approval_decisions
Target, decision, actor, reason and timestamp
sponsors
Sponsor identity/contact fields, status and visibility
sponsor_support
Support type, pledge, receipt, restrictions and evidence
welfare_cases
Minimal sensitive information, restricted notes and authorized assignment
announcements
Draft/published state, author, approver and publication window
audit_events
Actor, action, target, timestamp and safe metadata
notification_preferences
User delivery preferences
Names and relationships remain conceptual until schema design is approved.
Relationship outline
erDiagram
 USER_PROFILES ||--o{ ROLE_ASSIGNMENTS : receives
 USER_PROFILES ||--o{ INVITATIONS : sends_or_accepts
 USER_PROFILES ||--o{ CONSENT_RECORDS : records
 USER_PROFILES ||--o| PLAYERS : may_link_to
 FIXTURES ||--o{ PLAYER_AVAILABILITY : requests
 PLAYERS ||--o{ PLAYER_AVAILABILITY : responds
 FIXTURES ||--o{ SQUAD_SELECTIONS : contains
 PLAYERS ||--o{ SQUAD_SELECTIONS : selected
 TRAINING_SESSIONS ||--o{ ATTENDANCE : records
 FIXTURES ||--o{ TRANSPORT_PLANS : coordinates
 FINANCIAL_TRANSACTIONS ||--o{ APPROVAL_DECISIONS : reviewed_by
 OPENING_BALANCE_REQUESTS ||--o{ APPROVAL_DECISIONS : reviewed_by
 SPONSORS ||--o{ SPONSOR_SUPPORT : provides
 USER_PROFILES ||--o{ AUDIT_EVENTS : acts
Authorization
Supabase Auth establishes identity; leadership-managed assignments control roles.
Role assignment is validated server-side; users cannot grant themselves roles.
Use deny-by-default RLS and carefully scoped server-side functions.
Treasurer access does not imply welfare access, or vice versa.
Media sees approved publishable content only.
Sponsors/public receive explicitly published or shared fields only.
Ordinary users cannot edit audit events; corrections preserve history.
Never ship service-role credentials in browser code.
Opening balance integrity
Save proposal and evidence as a request.
Exclude pending requests from approved totals.
Record approval/rejection and reason by an authorized reviewer.
Enforce separation of duties once the club confirms policy.
Derive approved summaries from approved transactions only.
Use traceable reversals/amendments rather than silent deletion.
Before implementation, confirm retention periods, data access/correction procedures, consent wording, safeguarding rules and whether minors may be represented.

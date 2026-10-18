Timau Union FC — Phased Build Plan (Proposal)
Planning only. Do not implement until design and policies are approved.
Platform
Frontend: GitHub Pages.
Repository: jacqmurithi-ux/timau-union-fc; default branch main.
Backend: club-supplied Supabase project.
No Vercel.
Browser code uses public Supabase configuration/publishable keys only; never expose service-role secrets.
Supabase Auth, RLS and server-side functions enforce identity and permissions.
Phase 0 — Design/policy approval
Deliverables: feature flows, conceptual data model, screen/navigation specification and this phased plan.
Checklist:
[ ]
Approve roles and Chairman-controlled role assignment.
[ ]
Approve permissions for each module and record type.
[ ]
Approve finance approval and opening-balance lock rules.
[ ]
Approve fixture alert milestones and channels.
[ ]
Approve sponsor/well-wisher and transport-support tracking.
[ ]
Approve privacy notice, consent, retention and welfare access.
[ ]
Supply approved crest, colors and public contact details.
[ ]
Verify tournament dates/rules from an authoritative source.
Gate: no app code, migrations or production data changes before written approval.
Phase 1 — Repository/security foundation
Inspect repository and deployment settings; preserve existing files; document baseline; configure GitHub Pages; establish Supabase Auth, role, RLS and audit patterns; test unauthenticated and unauthorized paths.
Exit criteria: backend-enforced permissions and no service-role secret in repository or built assets.
Phase 2 — Identity and football operations
Implement invitations, role assignment, club/player records, fixtures, availability, squad selection, training attendance and transport readiness. Add T-7/T-3/T+1 alerts only after channel/schedule approval.
Exit criteria: role isolation works and fixture readiness is usable on mobile.
Phase 3 — Finance and approvals
Implement transactions, evidence, approval queue, opening-balance lock, approved summaries, traceable corrections/reversals and printable reports.
Exit criteria: pending/rejected items are excluded from approved totals; actions are authorized and auditable.
Phase 4 — Welfare, sponsors and public media
Implement restricted welfare workflows, sponsor pledge/receipt tracking and draft/approve/publish media workflow.
Exit criteria: public endpoints expose approved public fields only; role-isolation tests cover welfare and sponsor records.
Phase 5 — Validation and launch
Test mobile layouts, keyboard access, slow connections, errors, RLS, financial totals, opening-balance lock, public/private boundaries, invitations/revocation, KSh and Africa/Nairobi display, print layouts, backup/recovery and incident response. Club acceptance testing should use fictional data before live records.
Release checklist
[ ]
Design approval recorded.
[ ]
No secrets committed.
[ ]
RLS and server-side authorization reviewed.
[ ]
Financial totals and opening-balance lock tested.
[ ]
Public/private boundaries tested.
[ ]
Invitation and role revocation tested.
[ ]
Mobile/print layouts reviewed.
[ ]
Club owner approves launch.
Unconfirmed
Approval thresholds, exact role permissions, consent wording, retention periods, notification channels and tournament dates/rules must be confirmed, not invented.

# Sponsor Lead workspace — test checklist

The base Sponsor Lead migration and the evaluation/proposal migration were executed together on Union Test inside a transaction that was rolled back. This validates migration execution only; it does not prove authenticated role behavior. Complete the interactive checks below in a disposable test fixture with one account per role before merge. Do not run against production until reviewed and approved.

- [ ] Sponsor Lead can create/edit pipeline, packages, agreements, communications, benefits, requests, and pledge drafts.
- [ ] Sponsor Lead cannot write to `private.treasurer_records`, `private.tm_records`, or confirm a contribution receipt; attempts fail at the database boundary.
- [ ] Only Treasurer/admin can call `sponsor_lead_confirm_receipt`; receipt status and received amount cannot be changed by Sponsor Lead.
- [ ] Pipeline/contact details and full agreement terms are returned only to Sponsor Lead, Chairman, and admin; Treasurer receives agreement amounts and payment schedules only.
- [ ] Media Team receives only requests addressed to Media Team plus approved public sponsor data through the public-content RPC; Secretary receives only their requests.
- [ ] Public sponsor query contains approved records only, and the public payload never includes prospects, contacts, agreements, pricing, pledges, signed-file paths, or private notes.
- [ ] Agreement uploads are private in Storage; anonymous access and non-authorized roles are denied; signed URL access is granted only after role checks.
- [ ] Agreements expiring within 60 days appear in the renewal reminders.
- [ ] Sponsor Lead cannot alter Treasurer-confirmed receipt fields through direct REST/table access or RPC payload manipulation.
- [ ] Admin override requires a reason and audit row captures actor, timestamp, table/record, before/after JSON, and reason.
- [ ] Existing Sponsors tab and Finance / requisitions link still work; verify Chairman, Treasurer, Media Team, Secretary, Player, and Supporter workspaces remain unchanged.
- [ ] Validate all functions, RLS/storage policies, role combinations, and migrations against actual deployed schema before production.


## Verification evidence (2026-10-22)

- [x] Executed the full candidate chain in order: `20261022210000_sponsor_lead_workspace.sql`, then `20261022220000_sponsor_evaluation_proposals.sql`, inside a single transaction on Union Test.
- [x] The database tool returned without SQL error; the transaction was rolled back. No migration changes from this test were persisted.
- [x] Inspected the test project's migration history and catalog: the candidate migrations are not recorded as installed, and the sponsor-specific tables were not present before the rollback-only run.
- [x] Sponsor Lead JavaScript syntax had previously passed parser validation after import declarations were removed.
- [ ] Authenticated role-by-role RPC, direct-table and Storage tests remain required; migration execution is not authorization proof.
- [ ] Browser verification of scoring, Chairman risk approval, proposal merge fields, verified-fact warnings, version history, print/PDF, accepted-agreement linking and reminders remains required.
- [ ] Review stored proposal HTML for safe rendering before treating the UI as production-ready.

## Prospect evaluation and proposals (added 2026-10-22)

- [ ] Set evaluation weights in Chairman settings to values totalling 100%; verify invalid totals and missing keys are rejected.
- [ ] Score each criterion from 1–5 and compare the weighted percentage with a hand calculation; confirm strong (75–100), medium (50–74.99), weak (below 50) bands.
- [ ] Configure a restricted sponsor category; classify a prospect in that category and confirm the evaluation is risk-flagged.
- [ ] As Sponsor Lead, submit a risk-flagged prospect for pursuit; confirm it remains on hold pending Chairman approval and is not marked pursue.
- [ ] As Chairman, approve and decline pending risk decisions; verify evaluator history and audit rows preserve the decision and reason.
- [ ] Confirm pipeline can sort by weighted score and next follow-up; proposal follow-up dates appear in reminders.
- [ ] Create and edit each proposal template; starter templates contain placeholders only and no invented club facts/statistics.
- [ ] Generate a proposal from a selected prospect/package/template; confirm merge fields fill, live preview is editable, and unverified facts visibly say UNVERIFIED.
- [ ] Print proposal and use browser Print → Save as PDF; confirm Timau Union FC red branding is present.
- [ ] Confirm Sponsor Lead can save drafts but cannot approve/mark sent/accept/decline proposals; Chairman/admin approval is required before sent, and sponsor response requires sent status.
- [ ] Confirm accepted proposal is linked to an agreement; review the generated agreement draft before using it operationally.
- [ ] Confirm Treasurer receives proposal amount/status only, not private proposal text, evaluation scores, risk notes, or templates.
- [ ] Confirm non-authorized roles cannot call evaluation/template/proposal RPCs or read the private tables; public sponsor pages remain unchanged.
- [ ] As admin, edit a template or override proposal status with a reason; verify the audit row includes actor, record, before/after values, and reason.

## Current validation evidence

- [x] Both Sponsor Lead SQL migrations execute together on Union Test inside a transaction and roll back cleanly (no migration changes persisted).
- [x] Sponsor Lead JavaScript syntax check passed after the evaluation/proposal additions.
- [ ] Browser workflows and authenticated multi-role tests are still pending; migration rollback alone is not proof of RLS correctness.

## Security hardening follow-up — 2026-10-22

- [x] Added `20261022230000_sponsor_lead_security_hardening.sql` on `feature/sponsor-lead-workspace`.
- [x] Applied the hardening migration to Union Test after the base and evaluation/proposal migrations; Supabase migration tool returned `success: true`.
- [x] Static source check: `sponsor_lead_save_record` now rejects receipt-related keys for non-Treasurer/non-admin callers on both create and update paths.
- [x] Static source check: `sponsor_eval_save` rejects a missing or non-object risk-check payload.
- [ ] Runtime role test: Sponsor Lead cannot create a pledge containing receipt fields, change receipt fields on an existing pledge, or invoke receipt confirmation.
- [ ] Runtime role test: Treasurer can confirm receipts; other roles are denied.
- [ ] Runtime role test: a risk-flagged pursuit request remains on hold until a Chairman/admin decision; decline does not mark it pursued.
- [ ] Runtime role test: non-authorized roles cannot read prospect evaluations, proposal contents, templates, agreement terms, or signed documents.
- [ ] Runtime role test: proposal version history and accepted-proposal agreement linking behave as expected.
- [ ] Runtime role test: admin override reason and before/after audit data are recorded.
- [ ] Public sponsor query verified to return approved public sponsor records only.
- [ ] Browser test of proposal merge fields, verified-fact warnings, print/PDF and follow-up reminders.
- 

## Migration sequence reconciliation (2026-10-22)

- [x] Removed duplicate timestamp filenames from the branch migration chain. The four corrective migrations now have unique, ordered source timestamps: `20261022230000_sponsor_lead_security_hardening.sql`, `20261022231000_sponsor_evaluation_insert_alignment.sql`, `20261022232000_sponsor_eval_receipt_security_fix.sql`, and `20261022233000_sponsor_contribution_payload_guard.sql`.
- [x] Confirmed Union Test migration history shows the four corrective migrations were previously applied in order as `sponsor_lead_security_hardening_20261022230000`, `sponsor_evaluation_insert_alignment_20261022231000`, `sponsor_eval_receipt_security_fix_20261022230000`, and `sponsor_contribution_payload_guard_20261022231000` (Supabase generated unique applied versions). Renaming the repository files does not rewrite that existing history.
- [x] Confirmed sponsor-specific private tables exist in Union Test after the persistent hardening migrations.
- [ ] Fresh-database replay of the complete renamed source migration chain has not yet been performed; do not treat the source rename as proof of a clean bootstrap.

## Corrective migration verification (2026-10-22)

- [x] Applied `20261022230000_sponsor_eval_receipt_security_fix.sql` to Union Test; Supabase reported success.
- [x] Applied `20261022231000_sponsor_contribution_payload_guard.sql` to Union Test; Supabase reported success.
- [x] Queried installed function catalog: `sponsor_eval_save` and `sponsor_lead_save_record` remain SECURITY DEFINER with an empty search_path.
- [x] Confirmed the installed evaluation function references `requested_decision` and the approval-request fields.
- [x] Confirmed the installed contribution save RPC rejects receipt-related keys for non-Treasurer/non-admin callers, for inserts and updates.
- [ ] Authenticated Sponsor Lead/Treasurer/Chairman/Admin runtime tests. Not run: this SQL connection does not provide role-specific signed-in sessions.
- [ ] Verify risk approval/rejection transitions using authenticated sessions.
- [ ] Verify private RLS reads, proposal version history, agreement linking and administrative audit events end-to-end.
- [ ] Public approved-only sponsor listing and browser proposal/PDF tests.

**Evidence note:** the two corrective migrations are installed in Union Test and their installed function definitions were inspected. This is static/database-definition verification only; it is not evidence that authenticated role-specific tests pass. Production remains untouched; branch remains unmerged and undeployed.


## Release-gate execution results (2026-10-22, refreshed)

- [x] Inspected Union Test migration history and confirmed all four corrective migrations were applied successfully by the Supabase migration tool.
- [x] Queried Union Test catalog and confirmed the sponsor private tables exist, including prospects, prospect evaluations, agreements, contributions, proposal templates/versions and audit records.
- [x] Inspected installed function definitions: the evaluation RPC references the risk approval fields; the contribution save RPC rejects receipt-field payload keys for non-Treasurer/non-admin roles; the relevant functions remain SECURITY DEFINER with empty search paths.
- [ ] **Authenticated role-by-role RPC, REST/RLS and Storage tests — NOT RUN.** The available SQL connector does not create authenticated PostgREST sessions, so SQL catalog checks cannot establish the caller identity/role enforcement behavior.
- [ ] **Fixture coverage gap:** current Union Test membership query shows active Treasurer, Secretary, Chairman+Secretary and Media Team fixtures, but no confirmed active Sponsor Lead fixture; no disposable unauthorized-role fixture was confirmed in the query. A real Sponsor Lead account and a non-authorized account are required to complete the matrix.
- [ ] Browser interactions, proposal printing/PDF, and end-to-end proposal-to-agreement linking remain unverified.
- [ ] Fresh database migration replay remains unverified after filename reconciliation.
- [ ] Production migration, merge, and deployment have not been performed. These remain blocked on the unchecked release gates above; no private sponsor or financial data should be exposed to production until they pass.

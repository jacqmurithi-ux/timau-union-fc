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

## Prospect evaluation and proposals

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
- [ ] As admin, edit a template or change proposal status with a reason; verify the audit row includes actor, record, before/after values, and reason.

## Security hardening and migration verification

- [x] Added the receipt payload guard migration, rejecting receipt-related keys for non-Treasurer/non-admin callers on contribution inserts and updates.
- [x] Added the proposal transition guard migration `20261022234000_sponsor_proposal_state_transition_guard.sql` on `feature/sponsor-lead-workspace`.
- [x] Static review of the new transition function: `approved` requires a draft (or already-approved) proposal; `sent` requires approved; `accepted` or `declined` requires sent. These transition checks apply to Chairman and platform admin as well as other callers.
- [x] Static review: platform-admin status changes require a reason and are audit logged; elevated privileges do not bypass proposal state transitions.
- [ ] Apply the new transition migration to a disposable database or rollback-only transaction and verify it compiles against the full migration chain.
- [ ] Authenticated role test: Chairman cannot mark a draft as sent, nor record accepted/declined before sent.
- [ ] Authenticated role test: platform admin cannot skip states; admin status changes without a reason fail; authorized changes include reason in the audit row.
- [ ] Authenticated role test: Sponsor Lead cannot change proposal status; unauthorized roles cannot call proposal RPCs or read private proposal data.
- [ ] Runtime tests for Treasurer receipt confirmation, private Storage, accepted-proposal agreement linking and audit events remain outstanding.
- [ ] Browser proposal merge fields, verified-fact warnings, print/PDF, follow-up reminders, and clean migration replay remain unverified.

## Release status

- [ ] Authenticated role-by-role RPC, direct REST/RLS and Storage tests — NOT RUN.
- [ ] Browser workflows and fresh database migration replay — NOT RUN.
- [ ] GitHub Actions results must be rechecked on the latest branch head before merge.
- [ ] Production migration, merge and deployment have not been performed.

**Evidence note:** static source review only for the new proposal transition guard. No production database or website changes were made by this commit.
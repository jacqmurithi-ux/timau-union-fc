# Sponsor Lead workspace — test checklist

The candidate migration was syntax/DDL-checked on Union Test inside a transaction that was rolled back. This validates migration execution only; it does not prove authenticated role behavior. Complete the interactive checks below in a disposable test fixture with one account per role before merge. Do not run against production until reviewed and approved.

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

- [x] Base Sponsor Lead migration and evaluation/proposal migration execute together on Union Test in a transaction that was rolled back.
- [x] Sponsor Lead JavaScript syntax passes after import declarations are removed for parser validation.
- [ ] Authenticated role-by-role RPC and Storage tests are still required; migration execution is not authorization proof.
- [ ] Browser verification of scoring, Chairman risk approval, proposal merge fields, verified-fact warnings, version history, print/PDF, accepted-agreement linking and reminders remains required.
- [ ] Review stored proposal HTML for safe rendering before treating the UI as production-ready.

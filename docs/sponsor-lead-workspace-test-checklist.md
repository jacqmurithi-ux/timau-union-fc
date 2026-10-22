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

- [x] Candidate migration executes on Union Test inside a transaction and rolls back cleanly.
- [x] Sponsor Lead page JavaScript parses when treated as an ES module body.
- [x] Shared workspace link is present and hidden by the role-visibility code unless the user has the Sponsor Lead role or admin access.
- [ ] Authenticated role-by-role RPC and Storage tests are still required. Union Test does not currently have a dedicated Sponsor Lead test identity, so the migration rollback check must not be represented as a completed authorization test.
- [ ] Real browser verification of upload, reminder rendering, request workflow, edit/override UX, and report output remains required.

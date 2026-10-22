# Sponsor Lead workspace — test checklist

Run against Union Test after applying the migration in a rollback-capable test environment. Do not run against production until reviewed and approved.

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

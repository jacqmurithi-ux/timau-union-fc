# Treasurer workspace expansion — test checklist

Run against a dedicated test project before applying the migration to production. Use separate test accounts for Treasurer, Chairman, Platform Admin, Team Manager, Coach, another official, and two Sponsors. Do not seed fictitious financial transactions into production.

- [ ] Treasurer can create income, expense, budget, sponsor-fund, member-contribution, receipt and financial-report drafts; non-Treasurer officials cannot create or edit those records through RPC calls or direct table access.
- [ ] Treasurer can approve/reject/query pending requisitions and transport submissions; a submitted requisition is visible only to its submitter and finance reviewers.
- [ ] Team Manager and Coach can submit requisitions, see their own status, and cannot query another official's requisition by changing an ID.
- [ ] Sponsor A sees only sponsor-fund/contribution records whose `sponsor_user_id` is Sponsor A's authenticated UUID; Sponsor B cannot see Sponsor A's records.
- [ ] Treasurer opening-balance confirmation alone does not lock the amount. Chairman confirmation must match the exact amount; after both confirmations the row is locked.
- [ ] A locked opening balance cannot be changed by Treasurer or Chairman; Platform Admin override attempts require a reason and create an audit event. Verify the ledger remains reconciled after any approved correction.
- [ ] Chairman and Platform Admin can review/override allowed record statuses; audit rows include actor, timestamp, record ID, old/new data, reason and override flag.
- [ ] Approved income/expense/transport amounts create ledger entries; approved records cannot be edited/deleted and corrections use separate, audited adjustment/reversal entries.
- [ ] Receipt bucket is private; users cannot list/download another user's folder, anonymous uploads/downloads fail, and approved roles can read receipts only under the configured policy.
- [ ] A financial report is private as a draft or approved record and is returned by the public report RPC only after explicit `published` status.
- [ ] Existing Transport & logistics and Expenses & club finances records remain visible to finance officials; approve a TM transport plan using an explicitly confirmed total fare and verify it creates an expense plus ledger entry.
- [ ] Budget vs actual and overspend warnings use approved ledger totals only; test category and season boundaries before enabling production reporting.
- [ ] Test with direct REST/table requests and RPC calls as well as the UI; hiding tabs is not an authorization test.

## Known implementation boundary to verify

Member contribution rows use explicit member identifiers/details in payload; the migration does not guess existing membership-fee balances. Budget variance/overspend display and detailed monthly/season aggregation should be validated against real, approved ledger records before publishing reports.

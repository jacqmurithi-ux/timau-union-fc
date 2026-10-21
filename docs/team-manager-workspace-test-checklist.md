# Team Manager workspace — test checklist

## Current rollout status (21 October 2026)

The Union Test and Production role adapters, Team Manager workspace migration, and expense-ledger migration have already been applied in order. The database-level rollback-only expense workflow test passed on Union Test, and no test expenses or ledger entries were retained. **Do not reapply these migrations.** Continue with the interactive signed-in/browser checks below using Union Test accounts only. Do not create test expenses in Production.

For a future schema change, use the relevant environment adapter first, then the Team Manager workspace migration, then the expense-ledger migration; validate in Union Test before any separate Production rollout.

- [ ] Sign in as a Team Manager. Workspace shows Players, Fixtures & results, Activities, Import FKF roster, and the eight TM duty sections. News and Sponsors tabs are absent.
- [ ] As TM, call `club_save_record` for `news` and `sponsor`; both must fail. Try the same through the UI.
- [ ] Create a TM-owned player/fixture/activity record. Another non-admin role cannot edit it or change its publication status. TM can edit TM-owned records.
- [ ] As TM, try editing a player/fixture/activity record created by a different role; database function must reject it.
- [ ] As a non-TM role, attempt `tm_save_record`; it must fail. The welfare role can view only `discipline_welfare` records and cannot edit them.
- [ ] Create/edit a TM duty record. It saves as `draft`; edits reset approval. No duty record becomes public by default.
- [ ] Submit a transport plan with fare-per-player information and a Treasurer submission note. Verify the TM UI does not provide a money-approval action.
- [ ] As Chairman or active Platform Admin, edit a TM duty record and supply an override reason. Confirm `private.tm_record_audit` stores actor, timestamp, record ID, old/new JSON, old/new status, override flag, and reason.
- [ ] As Chairman or active Platform Admin, change publication status with a reason; confirm an audit row is written.
- [ ] As Player Welfare, verify welfare notes are visible, while squad, transport, and other TM sections are not returned.
- [ ] Verify Media Team and Sponsor Lead retain their existing News/Sponsors permissions when they do not also have the Team Manager role.
- [ ] Run existing workspace and public-site smoke tests; verify unapproved content remains private.


## Expense and Treasurer financial workflow
- [ ] As TM, submit transport, refreshments, kit/equipment, medical/first aid, venue/pitch, and other expense entries with category, description/payee/reference, amount (KES), and date. Submission is pending; no ledger total changes until an authorized reviewer approves it.
- [ ] As TM, edit a pending/rejected expense; it returns to pending and requires Treasurer review again. TM cannot edit an approved expense.
- [ ] As Chairperson, Secretary, and Treasurer in separate sessions, each approve another person's pending expense with a reason; verify exactly one negative expense entry is posted to `private.club_financial_ledger` and the club financial summary updates. Each may reject another person's expense with a reason and no ledger entry is posted.
- [ ] Verify roles outside Chairperson/Secretary/Treasurer/Platform Admin cannot approve/reject; direct authenticated table access is denied; anonymous users cannot call expense RPCs.
- [ ] As Platform Admin/Chairman, correct an approved expense with a reason; verify the compensating reversal, re-submission as pending, and old/new values in `private.club_financial_audit`.
- [ ] Verify every active club role can read the summary RPC, while only TM/Treasurer/Chairman/Platform Admin can see expense records. Treasurer cannot edit TM submissions.
- [ ] Confirm financial summary states are based only on posted ledger transactions; do not enter estimated income or opening balances to make totals look complete.


## All-role expense submission
- [ ] Sign in with each active club role and confirm the Expenses & club finances tab is available.
- [ ] Each role can submit an expense linked in its description to the role, duty/activity, payee and receipt/reference; submission remains pending until Chairperson, Secretary, or Treasurer review.
- [ ] Ordinary roles can see and edit their own pending/rejected expenses only; they cannot see other roles' expense records or edit another submitter's record.
- [ ] Treasurer, Chairman and Platform Admin can view all submissions; only Chairperson/Secretary/Treasurer/Platform Admin can approve or reject; Chairperson, Secretary, Treasurer and Platform Admin must each be denied when reviewing an expense they personally submitted. Approval posts to the shared ledger; no one can directly write ledger rows from the client.
- [ ] All active club roles can read the same financial summary, and the summary changes only after ledger transactions are posted.


## Mandatory expense self-approval and audit tests
- [ ] Submit one pending expense as Chairperson; verify Chairperson cannot approve or reject it, but Secretary or Treasurer can.
- [ ] Submit one pending expense as Secretary; verify Secretary cannot approve or reject it, but Chairperson or Treasurer can.
- [ ] Submit one pending expense as Treasurer; verify Treasurer cannot approve or reject it, but Chairperson or Secretary can.
- [ ] Attempt self-review through the UI and direct authenticated RPC for all three roles; all attempts fail without ledger or status changes.
- [ ] Verify successful approval audit action identifies the actual reviewing role, actor, timestamp, reason, old/new status; Platform Admin override is explicitly marked.
- [ ] Verify duplicate/concurrent review requests create at most one ledger entry and only one successful status transition.

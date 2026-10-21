# Secretary workspace expansion — test checklist

**Environment:** Union Test first. Do not apply the migration to Production until the SQL and negative permission checks pass.

## Workspace and drafts
- [ ] Secretary can access Secretary workspace; unrelated roles receive access denied.
- [ ] Existing Players, Fixtures & results, News, Sponsors and Activities remain accessible from the existing club workspace.
- [ ] Secretary workspace tabs cover Meetings & minutes, Correspondence, Registration & licensing, Membership register, Documents, Notices, Elections & appointments and Reports.
- [ ] New records are saved as drafts; editing resets status to draft.
- [ ] Public-facing reads expose approved content only; drafts and restricted fields never appear publicly.
- [ ] Chairman and Platform Admin can override records; verify actor, timestamp, old/new data, status and reason in the Secretary audit table.

## Finance and requisitions
- [ ] Secretary cannot create or edit Expenses & club finances from the shared workspace.
- [ ] Direct calls to finance write RPCs are rejected for Secretary.
- [ ] Secretary sees read-only aggregate financial summary only.
- [ ] Secretary can submit a requisition through Finance / requisitions.
- [ ] Secretary sees only requisitions submitted by their own auth UUID and sees updated status/review reason.
- [ ] Secretary cannot read another user's requisition by changing an ID or calling the RPC directly.

## Duplicate players
- [ ] Approval check detects name similarity when combined with date of birth or FKF number.
- [ ] Example: Denis Kinyua / Dennis Kinyua with matching DOB or FKF number shows a warning and matching record(s).
- [ ] Secretary can explicitly merge with a chosen canonical record, mark not duplicate with a reason, or cancel.
- [ ] Merge archives rather than deletes the duplicate, saves merged fields as a draft for review, and logs both records.
- [ ] FKF roster import runs the same duplicate check before inserting drafts; no automatic merge/delete.
- [ ] Test exact duplicate, near-match, same name with different DOB/FKF, and unrelated names.

## Privacy and storage
- [ ] Under-18 ID/consent documents are stored in the private `secretary-restricted-documents` bucket.
- [ ] Anonymous, Player, Coach, Team Manager, Treasurer and other unauthorized roles cannot list, download, upload, overwrite or delete restricted documents.
- [ ] Secretary, Chairman and Platform Admin can access restricted documents according to the approved need-to-know policy.
- [ ] Upload size and content-type limits are enforced; document paths do not expose public URLs.

## Regression
- [ ] Treasurer, Coach and Team Manager dashboards still load and keep their existing role guards.
- [ ] Existing finance ledger, expense and audit records are unchanged.
- [ ] Run JavaScript syntax checks and SQL contract/security tests before merge.


## Follow-up UI regression checks (fix/secretary-tabs-and-forms)
- [ ] Secretary page shows all 13 tabs: Players, Fixtures & results, News, Sponsors, Activities, Meetings & minutes, Correspondence, Registration & licensing, Membership register, Documents, Notices, Elections & appointments, Reports.
- [ ] Existing five sections load the existing club records and keep using the established `club_save_record` and `club_set_publication_status` RPCs.
- [ ] Meeting form captures type, date, venue, attendance/apologies, agenda, minutes, resolutions and action items.
- [ ] Correspondence form captures direction, sender/recipient, date, reference, status and follow-up due date.
- [ ] Registration form captures FKF/league status, registration and expiry dates, and restricted under-18 document notes.
- [ ] Membership form captures member/official type, role, terms, contacts and membership status.
- [ ] Documents form captures category and version; Notices capture audience, channel, recipient log and send status; Elections capture nominees, result and terms; Reports capture period, recipient and summaries.
- [ ] Secretary save/edit remains draft-only; Chairman/Admin approval/override remains reasoned and audited.
- [ ] Compare read-only financial summary against Treasurer-approved finance records/ledger; investigate discrepancies instead of treating displayed zeroes as authoritative.

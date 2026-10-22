# Sponsor Lead migration dependency reconciliation — PR #42

**Status:** BLOCKED — candidate-only; do not apply to production, merge, or deploy.
**Reviewed:** 2026-10-22
**Repository:** `jacqmurithi-ux/timau-union-fc`
**PR:** #42, branch `feature/sponsor-lead-workspace`
**Reviewed head:** `d9f2e047819ba03cf17dd71a5a76eb9b25f4c3c5`
**Production Supabase project:** `owvvimydkjsjlrmnzvdi`

## Executive finding

Read-only inspection of production migration history and metadata found no installed `private.sponsor_%` tables and no `public.sponsor_%` RPCs. Production migration history ends with `20261022043737_current_club_roles_authenticated_acl`; it contains no Sponsor Lead migration versions. Therefore, the new RPCs cannot be validated as replacements for installed Sponsor Lead functions, and a successful parse or transaction rollback is not proof of production compatibility.

No migration was applied, no production data was changed, and no deployment or merge was performed during this review.

## Evidence reviewed

- PR metadata: open, draft, unmerged; head `d9f2e047819ba03cf17dd71a5a76eb9b25f4c3c5`.
- Production migration history: no Sponsor Lead migrations.
- Read-only metadata query for `private.sponsor_%` tables and `public.sponsor_%` functions: returned no rows.
- Migration files on PR branch and their blob identities:
  - `20261022210000_sponsor_lead_workspace.sql` — blob `6475451f6059b5cce43fb5b642be42d3e5e69ecf`
  - `20261022220000_sponsor_evaluation_proposals.sql` — blob `460b8b3e25f27f32fa53433435203e8580ecbf02`
  - `20261022230000_sponsor_lead_security_hardening.sql` — blob `737765ddd0bf2dfb04983d89a797dbda9a57c69c`
  - `20261022231000_sponsor_evaluation_insert_alignment.sql` — blob `588cacd50756d6f19592a4c0fafd09062a7fd1c2`
  - `20261022232000_sponsor_eval_receipt_security_fix.sql` — blob `83ddebc96587da3161012acaddf846b424a1bff8`
  - `20261022233000_sponsor_contribution_payload_guard.sql` — blob `232ce3f936b4f4bcdb4c3e49c1cbe5b7c4d97a12`
  - `20261022234000_sponsor_proposal_state_transition_guard.sql` — blob `6fe9aaa885cb33af51d173bc5469c0b0f88448a3`
  - `20261022235000_sponsor_accepted_proposal_immutable.sql` — blob `0d03924d8319c31f64255ff3af0a6d9e3911650d`

## Migration dependency map

| Order | Migration | Required predecessor / contract | Reconciliation result |
|---|---|---|---|
| 1 | `210000 sponsor_lead_workspace` | Existing club schema helpers, `private.club_records`, `private.current_club_roles()`, `private.is_active_platform_admin(uuid)`, Supabase Storage schema and policies | Helper existence is known from prior metadata review; all referenced columns, grants and Storage policy interactions still need a full production contract check. Sponsor tables are absent in production. |
| 2 | `220000 sponsor_evaluation_proposals` | Migration 1 tables, especially prospects, packages, agreements, audit; auth user references | Structurally depends on migration 1. Creates evaluation fields `requested_decision` and `approval_requested` in the base evaluation table. |
| 3 | `230000 sponsor_lead_security_hardening` | Migrations 1–2 | Replaces base RPCs and guards. This is not a standalone migration. |
| 4 | `231000 sponsor_evaluation_insert_alignment` | Evaluation table and RPC from migrations 2–3 | Corrective replacement uses `requested_decision` and `approval_requested`; confirm exact insert/value cardinality and risk-approval behavior in an executable test. |
| 5 | `232000 sponsor_eval_receipt_security_fix` | Base contribution table and evaluation RPC | Replaces evaluation save and trigger guard. File comment says it was applied only to a designated Union Test project; that comment is not evidence of current production state. |
| 6 | `233000 sponsor_contribution_payload_guard` | Base save-record RPC and contribution table | Replaces save RPC to reject receipt-related payload fields. Must reconcile with all allowlisted fields, insert/update paths and trigger guard. |
| 7 | `234000 sponsor_proposal_state_transition_guard` | Proposal table, agreement table, prospect table, audit table and `sponsor_eval_can_manage()` | Enforces draft → approved → sent → accepted/declined for all roles. Acceptance creates/links a draft agreement. Requires lifecycle tests and idempotency checks. |
| 8 | `235000 sponsor_accepted_proposal_immutable` | Proposal save RPC signature and tables from migrations 1–2 | Replaces the 10-argument save RPC and blocks in-place edits after acceptance. Requires function-signature/dependency checks and tests after migration 7. |

**Version naming note:** the candidate filenames use 10-digit versions beginning `2026102221...` etc. Production migration history uses 14-digit versions. Confirm the migration runner's version normalization and ordering rules before applying this chain. Never rename already-applied migrations in place; use a new forward corrective migration if reconciliation requires a change.

## Specific corrections and checks required

### P0 — reconcile migration chain before any execution

1. Produce a machine-readable dependency inventory for every `CREATE OR REPLACE FUNCTION`, `DROP FUNCTION`, table, trigger, policy and Storage policy in all eight files. For each object, list its required tables/columns, helper functions, grants and prior migration.
2. Verify all referenced production prerequisites, especially `private.club_records` and its referenced columns, `private.current_club_roles()`, `private.is_active_platform_admin(uuid)`, `auth.users`, `storage.buckets`, and `storage.objects`. The current evidence confirms only helper-function existence from prior metadata review, not complete signature/permission compatibility.
3. Check function overload cleanup. Migration 2 drops the older 9-argument `sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date)` and creates the 10-argument version. Confirm no other overloads or dependent callers remain, and verify the final signature is exactly `(uuid,uuid,uuid,uuid,text,text,numeric,text,date,text)`.
4. Reconcile duplicate/revised corrective migration history. Migration names 2300–2350 are separate forward migrations; verify none has been applied under another name/version and ensure a fresh replay applies the corrections in this exact order. Do not rewrite migration history to hide prior application.
5. Check each file for a single consistent transaction strategy and migration-runner compatibility. The files contain explicit `BEGIN/COMMIT`; verify the runner does not wrap them in incompatible transaction handling.

### P0 — proposal state and immutability

6. The status guard must reject invalid transitions for Chairman and platform admin too: draft → approved; approved → sent; sent → accepted or declined. Test repeated calls, invalid skips, and retries after partial failures.
7. Acceptance currently attempts to reuse the latest agreement matching sponsor name and package, otherwise inserts a draft agreement. Validate whether sponsor name/package is a sufficiently unique business key; avoid linking an unrelated or closed agreement. Prefer an explicit agreement identity or a stronger, reviewed matching contract if necessary.
8. The accepted-proposal save guard blocks edits after acceptance. Verify other write paths cannot mutate accepted rows (including direct table privileges, other RPCs, triggers, and admin helpers); immutable-by-one-RPC is not database-wide immutability.
9. Verify audit history accurately records actor, before/after values, reason, status, and proposal version. Confirm the version number calculation is concurrency-safe; `max(version_no)+1` can race without locking/unique-retry handling.
10. Verify proposal edit/version status semantics. Saving a version currently inserts a version row with status `draft`; ensure the proposal status and version status cannot misrepresent an already-sent or declined proposal.

### P0 — authorization, receipts and storage

11. Test Sponsor Lead, Chairman, Treasurer, Media Team, Secretary, platform admin and an unauthorized authenticated user against every RPC. Also test anonymous and unauthenticated calls. A function being granted to `authenticated` does not establish role authorization.
12. Confirm Sponsor Lead cannot set or alter `receipt_status`, `received_amount_kes`, `treasurer_confirmed_by`, or `treasurer_confirmed_at` through either INSERT or UPDATE, template/JSON payload tricks, alternate RPCs, or direct table paths. Confirm only Treasurer/admin receipt confirmation is allowed and audited.
13. Verify the `sponsor-agreements` bucket is private; test anonymous, unauthorized user, wrong-club user, and authorized official access for upload, read, update, delete, and signed URL issuance. Ensure object paths cannot be used to cross agreement/group boundaries.
14. Confirm public pages expose only explicitly approved public sponsor content and never prospect contact details, private notes, contribution amounts, signed-document paths, agreements, evaluation history, or audit records.

### P1 — correctness and browser verification

15. Verify evaluation weights sum to 100 and validate all score/risk payloads server-side. Confirm risky pursuit cannot bypass Chairman approval and approval records a reason/actor.
16. Validate the evaluation insert column/value count and mapping, including `requested_decision`, `approval_requested`, `chairman_approved_by`, and `chairman_approved_at`.
17. Test proposal templates, merge fields, escaping/sanitization, preview, print/Save-as-PDF, reminders, and all role-based UI actions in a browser. Client-side controls are not security boundaries.
18. Run clean migration replay, SQL assertions, and runtime role tests against a disposable isolated database only if separately authorized. This report itself does not run or authorize that test environment.

## Required verification evidence before release

- [ ] Reviewed production schema contract export (tables, columns, constraints, indexes, triggers, policies, function signatures, grants).
- [ ] Dependency graph signed off against the exact PR head.
- [ ] Fresh ordered migration replay succeeds without warnings or manual edits.
- [ ] Static SQL checks and database assertions pass.
- [ ] Role matrix results include expected allow/deny outcomes for every RPC.
- [ ] Receipt spoofing tests fail for Sponsor Lead and unauthorized roles.
- [ ] Storage private-access and signed-URL tests pass.
- [ ] Public-content isolation tests pass.
- [ ] Proposal transition, acceptance, agreement matching, immutability, concurrency, and audit tests pass.
- [ ] Browser workflow and PDF/print checks pass.
- [ ] PR checklist and CI evidence updated with actual results.

## Current release decision

**NO-GO.** This is a static dependency and metadata reconciliation, not a runtime security certification. The production database has no Sponsor Lead objects according to the read-only checks performed, so applying later corrective migrations alone would fail or leave an incomplete feature. Keep PR #42 unmerged and production untouched until the prerequisite contract is verified and every P0 release gate has test evidence.


## Follow-up production contract inspection (read-only)

**Evidence captured after the initial report commit**; no writes were performed.

- Production still has no `private.sponsor_%` tables, no `public.sponsor_%` functions, and no sponsor-specific triggers/policies in the queried schemas.
- Production migration history currently ends at `20261022043737 current_club_roles_authenticated_acl`; no Sponsor Lead migration versions appear in the list.
- `private.current_club_roles()` exists with no arguments and returns `text[]`.
- `private.is_active_platform_admin(uuid)` exists and returns `boolean`.
- `private.club_records` exists with columns `id`, `record_type`, `data`, `publication_status`, `created_by`, `updated_by`, `approved_by`, `approved_at`, `created_at`, and `updated_at`. Its `record_type` constraint permits `player`, `fixture`, `news`, `sponsor`, and `activity`; publication status permits `draft`, `approved`, and `archived`. The approval consistency constraint requires approver and timestamp when approved.
- Existing Storage policies include gallery, homepage hero, secretary documents, and Treasurer receipts. The inspected output did not show any sponsor-specific Storage policies or a `sponsor-agreements` bucket row. Because the candidate migration intends to create the bucket and its policies, confirm bucket/policy creation and the interaction with existing broad Storage policies in an isolated test before production.
- The PR description says the first two Sponsor Lead SQL migrations were executed inside a transaction and rolled back on Union Test. That supports a limited transactional syntax smoke test only; it is not evidence of persistent installation, production compatibility, role isolation, Storage safety, or full replay of all eight migrations.

### Updated concrete blocker

The base Sponsor Lead migration references `private.club_records(id)`, which exists in production, but the read-only contract query alone does not prove all referenced function bodies, grants, Storage policy semantics, or table ownership/permissions are compatible. In addition, because no Sponsor Lead objects are installed, migrations 3–8 cannot be safely treated as standalone hotfixes. Reconcile the entire chain as one ordered release candidate and verify it from a clean schema before release.



## Focused code-level findings from the eight-migration review

These are static findings from the current PR head; they are not runtime test results.

### High priority: prevent post-send proposal content changes

The final `sponsor_proposal_save` replacement rejects edits to accepted proposals, but still permits Chairman/platform-admin edits to proposals whose status is `sent` or `declined` and leaves the status unchanged. That can alter the stored content of a proposal already sent to a sponsor without a fresh approval/send cycle. Decide the business rule explicitly. Recommended default: treat `sent`, `accepted`, and `declined` content as immutable; require a new proposal for changed terms, or explicitly return a changed sent proposal to draft with a new version and approval cycle. Preserve accepted immutability in all cases.

### High priority: proposal version concurrency

The final `sponsor_proposal_save` computes `version_no` with `max(version_no)+1`. Concurrent saves for the same proposal can select the same number and cause a unique-key violation; retries and audit/version writes need deterministic handling. Serialize per proposal (row lock on proposal before version calculation, or an equivalent safe sequence strategy) and test simultaneous saves.

### High priority: accepted-proposal immutability must cover every write path

The accepted-proposal guard is implemented in `public.sponsor_proposal_save`. The status RPC updates status and agreement linkage directly. Review every function and trigger that writes `private.sponsor_proposals`; enforce accepted-row immutability in a database trigger or a single controlled write path so no alternate RPC can mutate accepted content, status, or agreement linkage after acceptance. Verify table privileges prevent direct writes.

### High priority: agreement auto-linking uses a weak matching key

The acceptance RPC links the latest agreement matching sponsor name and package (including a null package match), without checking agreement status, dates, amount, or an explicit prospect/agreement identity. Similar sponsor names or a closed/expired agreement could be linked incorrectly. Prefer explicit selection/confirmation of an agreement or require a reviewed strong key and eligibility rules; otherwise always create a new draft agreement for Chairman review. Test duplicate sponsor/package combinations and concurrent acceptance.

### High priority: storage policy contract is incomplete

The base migration creates/forces the bucket to `public=false`, but the complete effective Storage authorization depends on every policy for `storage.objects`, bucket ID checks, folder/path checks, and any signed-URL issuing RPC. A private bucket flag alone is insufficient. The production inspection showed other feature policies on `storage.objects`; exact policy expressions and their behavior for the proposed bucket must be evaluated. Add explicit bucket-scoped policies and verify no existing policy unintentionally authorizes cross-feature access.

### Medium priority: trigger role matrix and audit completeness

The base `private.sponsor_workspace_guard()` allows Sponsor Lead/Chairman/admin to insert contributions and Treasurer/admin to change receipt fields; the corrected save RPC separately blocks receipt-related keys for callers without Treasurer/admin. Keep both checks, and ensure all paths (including insert payloads, future RPCs and any direct grants) enforce the same rule. The trigger's audit insert is specifically for administrative updates, while normal save RPCs write their own audit rows; test delete behavior and confirm deletes have an audit trail if deletes are intended to be supported.

### Medium priority: evaluation settings and risk approval tests

The settings RPC validates seven weights summing to 100, while evaluation scoring relies on the persisted JSON weights. Confirm no alternate write path can bypass that validator, validate restricted-category normalization, and test risk flags and restricted-category matches across all caller roles. The boolean `_chairman_approval` parameter exists on the evaluation RPC signature but should not be treated as proof of approval; only a verified Chairman/admin identity and the dedicated approval workflow should authorize risky pursuit.

## Evidence status matrix

| Area | Current evidence | Status |
|---|---|---|
| Production prerequisites | Read-only catalog inspection confirms club_records and two role helpers; no Sponsor Lead objects | Partial |
| Migration order | File-level dependency order inferred from references/comments | Static only |
| SQL execution | PR description reports first two migrations executed in rollback-only transaction on Union Test | Limited smoke test; not independently re-run here |
| Remaining six migrations | No clean full-chain execution evidence provided | Unverified |
| RPC authorization | Role checks visible in source; no runtime role matrix | Unverified |
| Receipt anti-spoofing | JSON key guard and trigger guard visible in source; no adversarial RPC tests | Unverified |
| Storage private access | Bucket is created private in source; effective policy behavior not verified | Unverified |
| Public-data isolation | Workspace RPCs shape role-specific payloads; no anonymous/public-page leakage test | Unverified |
| Proposal workflow | State guards and accepted-save guard visible in source; lifecycle tests outstanding | Static only |
| Concurrency | Version allocation uses max + 1; no concurrent test evidence | Concern identified |
| Audit completeness | Multiple RPCs write audit rows; delete/alternate path coverage not established | Unverified |

## Revised release gate

**NO-GO remains in effect.** Before any production change, correct or explicitly approve the sent/declined proposal edit semantics, make proposal version allocation concurrency-safe, establish database-wide accepted-proposal immutability, strengthen agreement matching, and complete the Storage policy contract. Then produce test evidence for the complete ordered migration chain and the role/security matrix. This review made no database writes.


## Follow-up corrective candidates (not runtime-verified)

Two forward migrations have been added after the original eight files, as separate commits on `feature/sponsor-lead-workspace`.

### 9. `20261022236000_sponsor_acceptance_no_ambiguous_agreement_match.sql`

- Replaces `public.sponsor_proposal_set_status(uuid,text,text)` with the same role checks, state machine, audit logging and function grants.
- Removes automatic lookup by sponsor name/package.
- On acceptance, creates a new draft agreement associated with the accepted proposal for explicit human review rather than silently reusing an existing agreement.
- This is a safety-first interim rule, not an explicit agreement-picker UI. If the business requires selecting an existing agreement, add a separate authenticated, role-guarded linking RPC with eligibility checks and audit logging.
- Still requires tests for duplicate sponsor/package records, expired/closed agreements, repeated acceptance, rollback behavior, and concurrent status calls.

### 10. `20261022237000_sponsor_agreement_storage_policies.sql`

- Adds explicit `storage.objects` policies scoped to bucket `sponsor-agreements`.
- Requires the first path segment to be a UUID for an existing sponsor agreement.
- Allows read access to Sponsor Lead/Chairman/admin and Treasurer/finance roles through the existing helper; upload/update to Sponsor Lead/Chairman/admin; delete to Chairman/admin.
- The current upload code uses `<agreement UUID>/<random UUID>-<filename>`, which matches the first-segment contract.
- The policies do not make the bucket public; the base migration sets `public=false`.

**Important Storage caveat:** PostgreSQL permissive RLS policies combine with OR. These new policies do not override or neutralize any other permissive policy that may also match `storage.objects`. Before release, inspect the exact installed policy expressions and prove every other policy is bucket-scoped so none grants access to `sponsor-agreements` unintentionally. Also test signed URL issuance and use, since an already-issued signed URL may remain usable until expiry according to Storage behavior.

### Evidence and release status

- Both files are source-level corrective candidates only; no SQL execution or authenticated Storage test was run by this update.
- The complete ten-migration ordered chain still needs a clean replay in an explicitly authorized disposable environment.
- No production migration, data change, merge, or deployment occurred.
- Release remains **NO-GO** until SQL parsing/replay, role-matrix tests, bucket policy interaction tests, signed-URL tests, agreement lifecycle/concurrency tests, and the previously listed proposal immutability/version-concurrency checks pass.


### Follow-up static review note — Storage policy execution context

A subsequent static review replaced direct policy subqueries against `private.sponsor_agreements` with `private.can_access_sponsor_agreement_object(text,text)`, a fixed-search-path `SECURITY DEFINER` helper that returns only a boolean decision. It validates the first path segment as a UUID, checks the agreement exists, and applies operation-specific roles. This avoids relying on authenticated users having direct table access inside policy expressions.

This remains **unexecuted candidate SQL**. The helper's effective privileges, function ownership, role helpers, all permissive policies on `storage.objects`, and signed-URL behavior must be validated against the target schema before release. The migration's `grant usage on schema private to authenticated` should be reviewed against the repository's baseline privilege model; it is not a substitute for table-level least privilege.

## Follow-up release blocker review — 2026-10-22

### Current branch state

- PR #42 remains open, draft, and unmerged.
- Added candidate migration `20261022238000_sponsor_proposal_immutability_and_version_integrity.sql` at commit `01a99fb609bdf9b71130791f7c2f275848d76701`.
- The migration adds a unique `(proposal_id, version_no)` index, a trigger blocking UPDATE/DELETE of accepted proposals, and a version trigger that locks the parent proposal and prevents version changes for accepted proposals. This is source-level candidate SQL only; it has not been executed. Before testing, verify the base tables' exact columns and constraints and confirm the unique index can be created against the full fresh chain.
- The save RPC already takes `FOR UPDATE` on an existing proposal before allocating the next version; the new version trigger additionally serializes version writes by locking the parent proposal. Concurrent save tests are still required, including duplicate-key/retry behavior and status changes racing with saves.

### Read-only Storage policy inspection

A read-only query of the current production `storage.objects` policies returned the existing gallery, homepage hero, Secretary documents, and Treasurer receipts policies. Their displayed predicates scope operations to their own bucket IDs (`fans-gallery`, `homepage-hero`, `secretary-official-documents`, `secretary-restricted-documents`, and `club-financial-receipts`). No policy in this result referenced `sponsor-agreements`. This is useful evidence that the currently observed policies are bucket-scoped, but does not prove no future/broader policy exists or that the proposed migration's effective policies behave correctly after installation. PostgreSQL permissive policies OR together, so re-check the complete policy set after replay in the test environment.

### Storage helper privilege finding

The production catalog query for `private.can_access_sponsor_agreement_object(text,text)` returned no rows, as expected because the candidate migration has not been applied there. Therefore the helper's owner, SECURITY DEFINER effective privileges, ACL, and schema-usage implications cannot be confirmed from production. The migration currently grants `USAGE ON SCHEMA private` to all `authenticated` users, which broadens namespace access relative to a least-privilege baseline. Do not assume this is harmless: inventory existing `private` schema grants and object grants in the test database, then choose a narrow policy-function placement/grant strategy that works with Postgres schema resolution without exposing private tables. Keep direct table privileges revoked.

### CI check

For the previously reviewed head `6205758bf725a88d88671bd2c6750cce936b4c44`, GitHub reported no commit status entries and only two PR-triggered workflow runs in the connector result: Treasurer workspace validation and Homepage hero validation, both successful. Neither result is Sponsor Lead SQL replay, Storage policy validation, role matrix, proposal concurrency, or immutability evidence. Recheck the latest head after all commits; a green unrelated workflow is not a Sponsor Lead release pass.

### Test-environment gate

The connected Supabase account lists a separate project named `Union Test` (`dzpquzfghapjodmrmavw`) as well as production (`owvvimydkjsjlrmnzvdi`). This confirms a candidate test project exists, but does not establish that it is disposable, resettable, isolated from real users/data, or authorized for a persistent full-chain install. No migration or test write was run in either project during this pass. The full ordered chain and role-by-role Storage tests remain pending until the test project's safety and authorization are confirmed.

### Remaining release blockers

- [ ] Verify all `private` schema and helper-function ACLs in Union Test; revise the broad schema `USAGE` grant if possible without breaking policy evaluation.
- [ ] Replay all eleven candidate migrations from a clean, explicitly authorized test database, checking filename version ordering/runner compatibility and migration dependencies.
- [ ] Test Storage read/upload/update/delete for Sponsor Lead, Chairman, Treasurer, platform admin, Secretary, Media Team, Player/Supporter, and anonymous users; include cross-agreement path attempts and signed URL issuance/expiry.
- [ ] Test two simultaneous saves to the same proposal, version-number uniqueness, save-vs-accept race, accepted proposal UPDATE/DELETE attempts through every available RPC/direct table path, and version-row UPDATE/DELETE attempts.
- [ ] Review the new trigger behavior with proposal status transition RPC and ensure all relevant table/function grants, trigger ownership and SECURITY DEFINER execution context are correct.
- [ ] Recheck CI on the current head and obtain SQL replay, role matrix, browser and release evidence specific to Sponsor Lead.

**Release decision: NO-GO.** No production changes, migrations, merges, or deployments were made. The new migration is a candidate, not verified protection until tested against the complete schema and every write path.
## Union Test persistent replay — 2026-10-22

User explicitly authorized use of the existing Union Test account and said it may be reset. We chose not to wipe the project: its existing identity, club, Treasurer, Secretary, media, homepage and Sponsor Lead test schemas/data were preserved. No production project was targeted.

### Applied candidate migrations

The following missing Sponsor Lead candidates were applied successfully to Union Test using the connected Supabase migration operation:

- `20261022234000_sponsor_proposal_state_transition_guard.sql`
- `20261022235000_sponsor_accepted_proposal_immutable.sql`
- `20261022236000_sponsor_acceptance_no_ambiguous_agreement_match.sql` (corrected to create/link the draft agreement while the proposal is still `sent`, then transition to `accepted`; this avoids the accepted-row trigger blocking the workflow)
- `20261022237000_sponsor_agreement_storage_policies.sql`
- `20261022238000_sponsor_proposal_immutability_and_version_integrity.sql`
- `20261022239000_sponsor_storage_policy_overlap_cleanup.sql` (additional corrective migration added after inspecting the actual policy catalog)

### Catalog checks after application

- All six migrations reported success; the migration ledger now records them.
- `sponsor-agreements` bucket exists and is private (`public=false`).
- Four operation-specific Sponsor Agreement policies remain: SELECT, INSERT, UPDATE and DELETE, each scoped to the bucket and calling `private.can_access_sponsor_agreement_object`.
- Found and removed four older permissive Sponsor Agreement policies (`sponsor agreements private read/upload/update/delete`) that OR-combined with the new policies and could have weakened the role-specific restrictions.
- The helper is owned by `postgres`, is `SECURITY DEFINER`, uses an empty fixed `search_path`, and grants EXECUTE to `authenticated`. Authenticated users have no direct SELECT on `private.sponsor_agreements`, no direct UPDATE on `private.sponsor_proposals`, and no direct DELETE on `private.sponsor_proposal_versions`.
- `authenticated` has USAGE on `private`; this was already effective at verification time. This remains a namespace privilege to review, but direct table privileges checked above remain denied.
- The unique `(proposal_id, version_no)` index exists. The catalog also showed an existing equivalent unique index/constraint, so the added index may be redundant and should be cleaned up in a follow-up before final release rather than claimed as a required control.

### Validation still incomplete

- No role-authenticated Storage API matrix was run; catalog inspection is not equivalent to upload/download/delete tests under each real identity.
- No live accepted-proposal lifecycle or concurrent save race was exercised with representative records. Function/trigger definitions and catalog presence were verified, not end-to-end behavior.
- Signed URL issuance, expiration, and access after role changes remain untested.
- Existing test project was not reset because its other workspace schemas and test data were present and could be valuable; the authorized reset was not necessary for applying the missing migrations. The replay was therefore against the existing populated test project, not a clean-from-zero database.
- GitHub CI at head `f463829af8362810f30cff5ea00dc80c0e5ed02a` reported no commit statuses and only two successful unrelated runs: Treasurer workspace validation and Homepage hero validation. Sponsor Lead SQL/security workflow evidence is still missing.

**Release decision remains NO-GO.** The migrations are persistently applied to Union Test only; production remains untouched, and PR #42 is open, draft and unmerged. Do not merge or deploy until authenticated role tests, lifecycle/concurrency tests, signed URL tests, redundant index cleanup, and Sponsor Lead-specific CI/browser evidence are complete.
## Union Test execution update — 2026-10-22

### Candidate migration applied

- User authorized use/reset of the existing Union Test account (`dzpquzfghapjodmrmavw`); no reset was performed because the project already contains other Timau Union FC work and its recorded migration history was not a clean blank slate.
- Applied candidate SQL from `20261022238000_sponsor_proposal_immutability_and_version_integrity.sql` through the Supabase migration action. Supabase reported success. The actual migration history now includes a recorded `sponsor_proposal_immutability_and_version_integrity` entry in addition to timestamp-named sponsor entries, so the migration history needs reconciliation before assuming a clean canonical replay.
- Before applying, corrected the accepted-proposal trigger to allow only a one-time `agreement_id` link when the accepted proposal had no link and all other columns remain unchanged. The trigger continues to reject other updates and deletes of accepted proposals.
- Added cleanup of the four legacy `sponsor agreements private {read,upload,update,delete}` policies because permissive policies are OR-combined and would otherwise bypass the new helper's stricter role rules.

### Post-application catalog checks

Read-only checks on Union Test returned: unique proposal-version index = 1; proposal immutability trigger = 1; version immutability trigger = 1; legacy broad sponsor Storage policies remaining = 0; helper-based sponsor Storage policies = 4; duplicate `(proposal_id, version_no)` pairs = 0; accepted proposals present in current test data = 0.

The Storage helper is owned by `postgres`, is `SECURITY DEFINER`, has an empty fixed search path, and its catalog ACL lists execution by `authenticated` and `postgres`. The migration grants `USAGE ON SCHEMA private` to `authenticated`; this remains a broad namespace grant to assess against the baseline, although direct private table grants were not added by this migration.

### Not yet verified

- There are no accepted proposals in the current test data, so the one-time agreement-link exception has not been exercised against a real acceptance workflow.
- No authenticated role-by-role Storage API tests were run. Catalog checks do not prove behavior for Sponsor Lead, Chairman, Treasurer, platform admin, Secretary, Media Team, Player/Supporter, or anonymous requests.
- No concurrent clients were used to test simultaneous saves, acceptance-vs-save races, or duplicate version allocation. The unique index and triggers are installed, but concurrency behavior still requires test evidence.
- Signed URL issuance, expiry, and use were not tested.
- The test project's migration history now has both timestamp-named candidate entries and a separately named applied entry. Reconcile this history before any attempt at a complete replay; do not reset the project blindly.

**Current release decision: NO-GO.** The candidate migration is installed in Union Test only and catalog checks passed, but acceptance workflow, role-by-role Storage behavior, concurrency, signed URLs, browser/PDF flows, and current-head CI remain unverified. Production remains untouched; PR #42 remains open and draft.
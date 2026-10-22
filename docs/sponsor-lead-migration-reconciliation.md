# PR #42 — Sponsor Lead migration dependency reconciliation

**Status:** BLOCKED — candidate report only  
**Repository:** `jacqmurithi-ux/timau-union-fc`  
**Branch reviewed:** `feature/sponsor-lead-workspace`  
**Reviewed head:** `d9f2e047819ba03cf17dd71a5a76eb9b25f4c3c5`  
**PR:** https://github.com/jacqmurithi-ux/timau-union-fc/pull/42  
**Production Supabase project:** `owvvimydkjsjlrmnzvdi`

## Executive finding

The eight Sponsor Lead migrations form a dependent sequence, but production's migration history currently contains none of them and the read-only metadata review found no `sponsor_%` public RPCs or Sponsor Lead tables. Therefore the proposed SQL is not an incremental patch to an installed Sponsor Lead schema: it is a new subsystem plus subsequent replacements/guards. It is **not ready for production execution**.

No migration was applied for this report. No production rows or schema were changed. This report records static source findings and read-only metadata evidence; it does not claim successful runtime security tests.

## Evidence reviewed

| Evidence | Result |
|---|---|
| PR metadata | PR #42 is open, unmerged, draft; head is `d9f2e047819ba03cf17dd71a5a76eb9b25f4c3c5`. |
| Production migration history | Listed migrations run through `20261022043737_current_club_roles_authenticated_acl`; no Sponsor Lead migration versions are present. |
| Production schema metadata | Prior read-only metadata query found no Sponsor Lead tables or `sponsor_%` public RPCs. Existing helpers `private.current_club_roles()` and `private.is_active_platform_admin(uuid)` are present. |
| Candidate migration source | All eight files fetched from the PR branch and reviewed for declared dependencies, function replacements, privilege changes, and workflow guards. |
| PR test checklist | States that browser interaction, authenticated role-by-role RPC/Storage tests, and PDF/print verification remain outstanding. |
| Runtime proof | Not available for the full chain. Static inspection is not a substitute for executing the exact chain and role tests. |

## Migration dependency map

Apply order below is the apparent dependency order based on source comments and function/table references. It is **not an approval to apply**.

| Order | Candidate migration | Dependency / purpose | Reconciliation result |
|---:|---|---|---|
| 1 | `20261022210000_sponsor_lead_workspace.sql` | Base private sponsor tables, role-guarded RPCs, audit records, private agreement bucket and Storage policy. | Requires production compatibility checks for referenced helper functions, role names, existing schema objects, bucket policies, and all table/column definitions. No Sponsor Lead base schema is installed in production. |
| 2 | `20261022220000_sponsor_evaluation_proposals.sql` | Evaluation settings/history, templates, proposals/versions, evaluation and proposal RPCs. | Explicitly depends on migration 1. Replaces/creates multiple RPCs; must be checked against the exact base definitions and all referenced columns. |
| 3 | `20261022230000_sponsor_lead_security_hardening.sql` | Hardens contribution receipt payloads and evaluation insert logic. | Depends on functions/tables from 1–2. Later migrations replace overlapping function definitions; retain only after consolidated final-definition review. |
| 4 | `20261022231000_sponsor_evaluation_insert_alignment.sql` | Corrects evaluation insert column/value alignment and approval fields. | Replaces `public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean)`; must be reconciled with the final evaluation table columns and caller payload. |
| 5 | `20261022232000_sponsor_eval_receipt_security_fix.sql` | Further corrects evaluation approval mapping and contribution receipt guard. | Overlaps migration 3 and later migration 6. Its header says it was applied only to Union Test, but production history has no corresponding Sponsor Lead migration. Verify actual environment/history before treating this as deployed evidence. |
| 6 | `20261022233000_sponsor_contribution_payload_guard.sql` | Rejects receipt-related keys on contribution INSERT/UPDATE through the generic save RPC. | Replaces `public.sponsor_lead_save_record(text,uuid,jsonb,text)`; this is a security-sensitive final-definition collision with migration 1/3. Consolidate and test all payload paths, not only the expected UI. |
| 7 | `20261022234000_sponsor_proposal_state_transition_guard.sql` | Enforces proposal status transitions and accepted-agreement linking/creation. | Replaces `public.sponsor_proposal_set_status(uuid,text,text)`; needs lifecycle tests and validation of matching-agreement logic and audit events. |
| 8 | `20261022235000_sponsor_accepted_proposal_immutable.sql` | Prevents in-place edits to accepted proposals. | Replaces `public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date,text)`; must be checked together with migration 2's original function and migration 7's status rules. |

## Specific corrections required before execution

### A. Make migration history and the repository chain unambiguous

1. Produce one authoritative ordered migration manifest. Confirm the exact eight filenames are unique and that no earlier test-only migration was applied under an alternate filename/version.
2. Reconcile the known historical naming discrepancy: prior Union Test records reportedly used names such as `sponsor_eval_receipt_security_fix_20261022230000` and `sponsor_contribution_payload_guard_20261022231000`, while the current branch uses timestamps `20261022232000` and `20261022233000`. Do not rename or replay blindly; compare actual schema state and migration ledger first.
3. Run a **fresh disposable database replay** of the exact committed chain from a clean baseline. The existing report that two migrations ran in a rollback-only transaction is not evidence that all eight migrations replay in order or that they persist correctly.
4. Verify whether each migration is transaction-safe as authored and whether the migration runner wraps it in a transaction. Avoid nested/duplicated transaction assumptions.

### B. Consolidate overlapping function definitions

The following functions are defined or replaced in multiple migrations and need a final-definition matrix with argument signature, return type, owner, SECURITY DEFINER status, search path, grants, role checks, affected tables, and expected UI callers:

- `public.sponsor_lead_save_record(text,uuid,jsonb,text)`
- `public.sponsor_eval_save(uuid,jsonb,jsonb,text,text,boolean)`
- `public.sponsor_proposal_save(uuid,uuid,uuid,uuid,text,text,numeric,text,date,text)`
- `public.sponsor_proposal_set_status(uuid,text,text)`

Correction: review the **last effective definition** of each function, not just each migration independently. Ensure no later replacement silently drops a guard, audit write, or validation. Keep `SECURITY DEFINER` functions on an empty/fixed search path, schema-qualify referenced objects, and explicitly revoke default/public execution before granting only intended roles.

### C. Validate contribution receipt boundaries

1. Treat all contribution receipt fields as Treasurer/admin-only, including on INSERT, UPDATE, and unexpected JSON keys. Review `receipt_status`, `received_amount_kes`, `treasurer_confirmed_by`, and `treasurer_confirmed_at` in every write path.
2. Confirm Sponsor Lead cannot confirm receipt by supplying forged JSON, changing table selectors, or invoking an RPC directly.
3. Confirm authorized Treasurer actions are audited with actor, before/after state, and reason where required.
4. Confirm the generic save RPC uses a strict table/column allowlist and cannot be used to write to arbitrary private tables.

### D. Validate proposal state and record integrity

Required transition tests for every caller, including Chairman and platform admin:

- draft → approved: permitted only to authorized approver.
- approved → sent: permitted only after approval.
- sent → accepted or declined: permitted only after sent.
- invalid/backward transitions: rejected, including admin override unless a separately documented and approved exception exists.
- accepted proposal edit: rejected for Sponsor Lead, Chairman, and admin; a new proposal is required.
- acceptance: links only to the correct matching agreement or creates exactly one draft agreement; repeated requests must not create duplicates.
- versions and audit records: verify actual status/content/version values, not merely that a row is inserted.

The current state guard and accepted-proposal guard are code candidates only; neither has been executed against production.

### E. Verify private Storage and public isolation

1. Confirm `sponsor-agreements` is private and direct anonymous access is denied.
2. Test object read/write and signed-URL generation with unauthenticated users, Sponsor Lead, Treasurer, Chairman, admin, and unrelated roles.
3. Check that an object path cannot be changed to access another agreement's file.
4. Inspect every public sponsor query/view/policy to ensure only explicitly approved public fields are exposed; exclude private contacts, prospect notes, financial details, signed agreements, proposal drafts, and audit data.
5. Verify RLS and grants directly from catalog metadata after migration replay; policy names alone are not evidence of isolation.

## Required verification evidence

The release gate is satisfied only when the report can link to or record all of the following:

- [ ] Clean-baseline replay of all eight migrations in exact order, with exit/result evidence.
- [ ] Post-replay schema snapshot: tables, columns, constraints, indexes, triggers, policies, buckets, functions, owners, grants.
- [ ] Role matrix for Sponsor Lead, Treasurer, Chairman, platform admin, Media Team, Secretary, and unauthorized user, covering allowed and denied RPC calls.
- [ ] Receipt spoofing tests for both insert and update payloads.
- [ ] Private Storage anonymous/role tests and signed URL access tests.
- [ ] Public query/API inspection demonstrating approved-only public fields.
- [ ] Proposal lifecycle tests, accepted-record immutability, agreement deduplication, and audit/version assertions.
- [ ] Browser tests for evaluation forms, templates/merge fields, unverified-fact warnings, preview/print/PDF, reminders, and failure messages.
- [ ] CI result for the reviewed head commit and reviewer sign-off on remaining exceptions.

## Environment safety and release decision

- **Production:** read-only metadata evidence only; no migrations or data changes made by this review.
- **Union Test:** no changes made as part of this report.
- **Website / PR:** no merge or deployment performed.
- **Decision:** **NO-GO** until dependency reconciliation and the evidence checklist above are complete.

Do not apply this chain to production simply because individual SQL files parse or a subset once ran in a rollback-only transaction. The next safe technical step is to reconcile the migration ledger and final function definitions, then run a reproducible clean-chain test in a disposable environment before any production plan is considered.

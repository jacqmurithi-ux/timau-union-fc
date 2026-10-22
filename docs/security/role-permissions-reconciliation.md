# Security reconciliation: internal editing, approval, and publication

**Status: REVIEW REQUIRED — NOT APPROVED FOR DEPLOYMENT**  
**Branch:** `security/separate-edit-approval-publication`  
**Scope:** Existing role permissions, Coach navigation, database RPC authorization, and public publishing.  
**Production database:** No changes made by this branch.

## Executive finding

The deployed `private.role_can_manage_record(_roles, _type)` helper currently combines record-management eligibility with permissions used by `public.club_set_publication_status`. It returns true for the Coach role on `player`, `fixture`, and `activity`. The publication RPC calls this helper to authorize approval/status changes. Therefore, Coach internal access can unintentionally confer approval/status authority on those shared record types.

The same helper is used by `public.club_get_workspace_bundle` to decide which records are included and to populate a `can_approve` flag. This makes the frontend's record access and approval affordances rely on a combined permission concept.

The dedicated Coach-record path is better separated: `coach_save_record` creates/edits Coach records as drafts; `coach_set_publication_status` explicitly limits status changes to Chairman or active Platform Admin. Keep that path and the existing Coach navigation intact.

Private schemas currently have explicit deny-all direct-access RLS policies for `club_records`, `coach_records`, `tm_records`, `secretary_records`, and `tm_record_audit`. Access is mediated by security-definer RPCs, so each RPC must independently enforce authorization. RLS alone does not repair an overly permissive security-definer function.

## Role-by-role reconciliation

This matrix distinguishes observed/current paths from the recommended security boundary. It is not a grant of new permissions.

| Role | Internal access/editing (existing intent) | Approval/publication boundary |
|---|---|---|
| Platform Admin | Full operational access through explicit admin checks | May override/approve where current workflow permits; preserve audit/reason requirements |
| Chairman | Club oversight and current broad record access | Current explicit approver for Coach records; retain existing club oversight pending agreed approval matrix |
| Vice Chairman | Role exists; current code does not establish a universal content approval grant | Do not infer approval rights from navigation visibility; confirm intended delegation |
| Team Manager | Owns squad administration, match-day, transport, team sheets, and related internal records; current RPC supports TM editing | Do not infer public publishing from internal management; preserve current workflow only after each RPC is checked |
| Coach | Own Coach records; read-only coach-relevant squad, fitness, discipline summaries, fixtures, and activities | Must not approve/publish shared player, fixture, or activity records merely because Coach can manage/read them; Coach-record publication remains Chairman/Platform Admin |
| Secretary | Manages Secretary records and designated club content, including current eligible record types | Separate editing from publication; preserve any existing approval workflow only when its authority is explicit |
| Treasurer | Finance/requisition/ledger operations through finance-specific RPCs | Finance permissions must not imply public content approval |
| Sponsor Lead | Sponsor records/proposals and related sponsor workflow | Sponsor editing/proposal authority must not imply public publication authority |
| Media Team | Media/news and media workflow | Can prepare internal/publication drafts; public release requires the explicitly approved publishing role/workflow |
| Player Welfare | Restricted welfare/discipline access through purpose-specific paths | No public publication of restricted welfare data; Coach receives only allowlisted summaries |
| Sponsor / Supporter / Player / other read-only roles | Only the scoped read-only or own-record views implemented for that role | No approval, editing, or publication unless separately authorized by an explicit database rule |

**Important:** The live database and current repository do not provide a single, unambiguous approved matrix for every role's approval authority. In particular, Vice Chairman delegation and the exact publishing rights for Team Manager, Secretary, and Media Team must not be guessed. The correction should separate the concepts first, then encode only the confirmed approval matrix.

## Recommended correction design

1. Introduce separate internal-management and approval predicates, with distinct names and explicit role/type allowlists.
2. Keep `role_can_manage_record` (or its replacement) for read/edit eligibility only; do not call it from a publication RPC as a substitute for approval authorization.
3. Update `club_set_publication_status` to use the approval predicate, checking the active Platform Admin status separately. The Coach must fail closed for shared `player`, `fixture`, and `activity` publication changes.
4. Update `club_get_workspace_bundle` so its `can_approve` field reflects the approval predicate, while record visibility/editing continues to use the internal-access predicate.
5. Preserve `coach_get_dashboard`, `coach_save_record`, `coach_set_publication_status`, and current Coach navigation. Coach must retain its legitimate read-only and own-record editing paths.
6. Audit all other publication RPCs and their grants: `tm_set_publication_status`, Secretary publication functions, media/public-content functions, sponsor/content functions, and homepage/public-gallery publishing functions. No frontend-only check is sufficient.
7. Keep private-schema direct client access denied. Retain audit records and reason requirements for privileged overrides and publication decisions.
8. Verify every public-facing query/view/RPC filters to explicitly approved content and does not expose private draft or restricted records.

## Regression test matrix (required before merge/deployment)

- Coach can open the existing Coach dashboard and navigate its existing sections.
- Coach can create and edit their own Coach records; edits reset status to draft.
- Coach can read the currently allowed squad/fitness/discipline summaries without receiving restricted welfare notes.
- Coach cannot approve, archive, or return shared player/fixture/activity records to draft through direct RPC calls.
- Coach cannot call any alternate publication RPC to bypass the restriction.
- Coach cannot edit another Coach's private records unless separately and explicitly authorized.
- Chairman and active Platform Admin retain existing authorized review/override paths, including required reasons and audit entries.
- Team Manager, Secretary, Media Team, Sponsor Lead, Treasurer, Vice Chairman, Welfare, Player, Sponsor, and Supporter retain their legitimate access; no role gains approval power by being able to edit.
- Anonymous/public visitors see only explicitly approved public-safe records; drafts, archived items, private finance, and welfare data remain hidden.
- Direct SELECT/INSERT/UPDATE/DELETE on private tables remains denied to `anon` and `authenticated`.
- Verify function EXECUTE grants, error paths, and security-definer search paths.
- Test a transaction/rollback in a non-production test project before applying any migration.

## Deployment guardrails

- This document is a review artifact only.
- No migration is included or applied here because the full approved approval matrix is not yet established and the publication RPCs need complete cross-workspace reconciliation before rewriting.
- Next implementation step: agree the approver matrix, then prepare a candidate SQL migration plus rollback and RPC-level tests on a separate review change.
- Do not merge or deploy until the SQL diff, regression results, and navigation check have been reviewed.

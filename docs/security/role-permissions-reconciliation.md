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

This matrix is a reconciliation of the existing roles and the previously provided role/approval guidance. **Keep every role and its current approval authority exactly as already defined.** This work must not redesign, broaden, narrow, or reassign role responsibilities; it only separates internal record access/editing from approval and public publication enforcement.

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

**Role-preservation instruction:** Do not change or reinterpret the existing role/approval guidance to resolve the implementation gap. Treat the current approved role matrix as authoritative. Inspect the existing functions and policies to recover each role's current rights, then enforce those same rights through separate checks for internal access/editing, approval, and public publication. Where code paths disagree with the existing guidance, correct the implementation to match the guidance; do not change the guidance to match a faulty code path.

## Recommended correction design

1. Introduce separate internal-management, approval, and publication predicates with explicit role/type allowlists that preserve the current approved role matrix exactly.
2. Keep `role_can_manage_record` (or its replacement) for read/edit eligibility only; do not call it from a publication RPC as a substitute for approval authorization.
3. Update `club_set_publication_status` to use the approval predicate, checking the active Platform Admin status separately. The Coach must fail closed for shared `player`, `fixture`, and `activity` publication changes.
4. Update `club_get_workspace_bundle` so its `can_approve` field reflects the approval predicate, while record visibility/editing continues to use the internal-access predicate.
5. Preserve `coach_get_dashboard`, `coach_save_record`, `coach_set_publication_status`, and current Coach navigation. Coach must retain its legitimate read-only and own-record editing paths.
6. Audit all other publication RPCs and their grants: `tm_set_publication_status`, Secretary publication functions, media/public-content functions, sponsor/content functions, and homepage/public-gallery publishing functions. No frontend-only check is sufficient.
7. Keep private-schema direct client access denied. Retain audit records and reason requirements for privileged overrides and publication decisions.
8. Verify every public-facing query/view/RPC filters to explicitly approved content and does not expose private draft or restricted records. Preserve each role's existing authorized publishing rights; this is a separation-of-permissions change, not a role redesign.

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

## Findings from live RPC review

The pre-fix production database was inspected read-only. The relevant authorization paths were:

- `club_set_publication_status`: called `role_can_manage_record`, so Coach's shared-record management eligibility also permitted publication-status changes for player, fixture, and activity records. This has now been corrected in production.
- `club_get_workspace_bundle`: used the management predicate for both record inclusion and each record's `can_approve` flag. Record visibility now retains the original predicate, while approval metadata uses the separate approval predicate.
- `coach_set_publication_status`: already restricts Coach-record status changes to Chairman or active Platform Admin and requires a reason. Preserve it.
- `tm_set_publication_status`: separately permits Team Manager, Chairman, and Platform Admin; preserve this independent workflow.
- `secretary_set_status`: Secretary may review their own record status, but approval itself is explicitly limited to Chairman or Platform Admin. Preserve it.
- `sponsor_proposal_set_status`: publication/proposal transitions are separately limited to Chairman or Platform Admin; Sponsor Lead management eligibility does not itself authorize the state transition.
- `homepage_hero_save/remove/expire_from_workspace`: explicitly use the existing Admin-or-Media-Team helper and audit changes. No role changes are proposed for these functions.
- `get_published_club_content`: returns only approved records and projects allowlisted public fields by record type. Preserve that public-safe filtering.

This is a scoped first correction, not a claim that every publishing surface has been exhaustively penetration-tested. The candidate migration leaves the above separate workflows untouched and does not change direct-table RLS policies or function grants for existing public RPCs.

## Applied correction

- `supabase/migrations/20261023100000_separate_club_record_approval_authority.sql` introduces a private approval predicate distinct from `role_can_manage_record`, changes `club_set_publication_status` to use the approval predicate, and updates `club_get_workspace_bundle` so record visibility remains based on the existing management rules while `can_approve` is based on the approval predicate.
- The applied correction preserves the existing Chairman, Secretary, Media Team/news, Sponsor Lead/sponsor, and Team Manager shared-record approval paths represented by the deployed helper. It excludes Coach from approval for shared player, fixture, and activity records.
- `supabase/tests/20261023100000_separate_club_record_approval_authority.sql` contains rollback-only predicate regression checks for Coach denial, retained Coach internal management eligibility, and preservation of existing Team Manager/Secretary/Media/Sponsor Lead/Chairman approval paths.
- The candidate migration and paired regression suite were executed together against the non-production Union Test project in a transaction that was rolled back. SQL creation, predicate checks, simulated direct RPC denial for Coach, retained internal record visibility, top-level/per-record approval metadata, allowed paths for Secretary/Team Manager/Media Team/Sponsor Lead/Chairman, and publication audit reasons all passed. The test harness temporarily substitutes `private.current_club_roles()` to simulate roles because the test project has no production-style `private.role_assignments` table; the rollback restores the original function and removes fixtures. No test data or candidate schema changes were retained.

## Production application and verification

- Migration `separate_club_record_approval_authority` was applied to the production Timau Union FC Supabase project on 2026-10-23 and appears in the production migration history.
- The candidate migration and expanded regression suite passed on Union Test in a rollback-controlled transaction; test fixtures and temporary helper overrides were rolled back.
- After production application, a rollback-only production RPC test temporarily simulated a Coach role by swapping the Sponsor Lead assignment for a Coach assignment on the same account. Direct approval of a shared player record was denied; internal record visibility remained available; top-level and per-record `can_approve` flags were false. Secretary's existing allowed status path and Sponsor Lead's sponsor-record path succeeded, with audit reasons verified; the transaction was rolled back.
- A second rollback-only production check confirmed `coach_get_dashboard()` returns its expected fields and `coach_set_publication_status()` still denies Coach publication changes. The test role assignment was rolled back. Production currently has no active Coach assignment, so a real Coach account/browser session could not be exercised.
- Post-application inspection confirmed private record/audit tables retain RLS enabled and the deny-all direct-access policies for `anon` and `authenticated`; existing public RPC execute grants were unchanged. Production migration history records the applied migration.
- Security advisors still report the same existing broad categories of security-definer RPC warnings and private RLS-without-policy informational notices. Those findings predate this change; this migration did not alter those other functions or policies.
- No role responsibilities or frontend navigation files were changed. The Coach dashboard and publication functions retain their separate existing rules.

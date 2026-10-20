# Phase 2 — Private club management workspace

**Status: draft implementation only. Not deployed. The database migration has not been applied.**

## Included in this branch
- `app/workspace.html`: mobile-first private workspace interface.
- `app/workspace.js`: loads and writes through protected Supabase RPCs; no direct table writes.
- `supabase/migrations/20261020220000_phase_2_club_workspace.sql`: proposed private record store and RPC boundary.
- Member access page link to the workspace, shown only when the existing access-status RPC reports an approved active club role.

## Record types
- Players
- Fixtures and results
- News
- Sponsors
- Club activities

All records are drafts on creation. Editing a record resets it to draft. Only Chairman or Secretary can approve, unpublish, or archive records. The public read function returns approved records only and explicitly allowlists public fields rather than returning the complete private JSON payload.

## Proposed role matrix

| Role | Read in private workspace | Create/edit drafts | Approve public content |
|---|---|---|---|
| Chairman | All types | All types | Yes |
| Secretary | All types | All types | Yes |
| Team Manager | Players, fixtures, activities | Same types | No |
| Coach | Players, fixtures, activities | Same types | No |
| Media Team | News | News | No |
| Sponsor Lead | Sponsors | Sponsors | No |
| Treasurer / Vice Chairman | No operational record types by default | No | No |

Platform Admin is separate from club roles and does not automatically receive club record permissions.

## Critical database compatibility gate
The production project currently has the Phase 1 access workflow in the `private` schema and its `private.role_assignments` table. The separate Union Test project has a different identity/membership design, including `public.club_memberships` and `public.role_assignments`. **Do not apply this migration to either environment until the role helper is reconciled and tested against the intended schema.** In particular, the draft migration's `private.current_club_role()` currently targets the production-style private access schema; it is not directly compatible with Union Test's public membership schema.

## Required before production
1. Review every SQL statement and the rollback strategy.
2. Adapt and test the migration against a dedicated test schema that matches production, or deliberately port the identity layer first.
3. Test role-positive and role-negative cases using separate accounts for Chairman, Secretary, Team Manager, Media Team, Sponsor Lead, and a pending/revoked user.
4. Verify no role can edit another role's record type by guessing an ID.
5. Verify public RPC returns only approved rows and never exposes private/unapproved fields.
6. Run Supabase security advisors and inspect grants on every RPC/table.
7. Obtain explicit approval before applying any production migration.
8. Deploy from GitHub `main` to GitHub Pages only after acceptance; no Vercel.

## Known current limitations
- The public website is not yet connected to the published-content RPC. Its existing public placeholders remain until the database migration is reviewed, tested, and deployed.
- The workspace currently uses a generic record form for each record type. Dedicated public profile layouts, image/file upload, audit-history screen for club records, and richer fixture/standings support are later implementation tasks, not silently claimed as complete.
- No migration was applied and no production database rows were changed by this branch.

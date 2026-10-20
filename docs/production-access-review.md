# Production access workflow — pre-application review record

Status: **Draft only — not applied to production, not deployed, tests not run.**

## Confirmed target and read-only findings
- Supabase project: Timau Union FC, ref `owvvimydkjsjlrmnzvdi`, PostgreSQL 17.11, active.
- No tables found in the production `public` schema.
- No `private` schema found before this draft.
- The Supabase migration-list tool returned an empty application migration list.
- The inspected migration-like tables were service-owned `auth.schema_migrations`, `storage.migrations`, and `realtime.schema_migrations`; these are not evidence of application migration history.
- Existing `app/index.html` was a placeholder. The current access UI is being drafted only on this branch.
- No production rows have been changed by these read-only checks or by editing this Git branch.

## Draft artifacts
- `supabase/migrations/20261020170000_platform_access_workflow.sql`
- `supabase/rollback/20261020170000_platform_access_workflow.rollback.sql`
- `docs/platform-admin-bootstrap.sql`
- `app/index.html` and `app/access.js`

## Important release gates
1. The owner confirmed that the production backup is verified. However, the connected GitHub account returned HTTP 404 for `jacqmurithi-ux/chama-live-backups`, so the `prod-backup` workflow run could not be independently opened or inspected in this session. Keep the confirmation, but attach the workflow run URL or restore-check evidence before any production DDL.
2. The migration is not yet applied. The bootstrap SQL must only be run after migration review and approval, and only after creating and verifying the chosen email account.
3. The `private` schema must be confirmed absent from Supabase Data API exposed schemas. Confirm the migration role owns the SECURITY DEFINER functions and bypasses RLS as expected.
4. Configure Supabase Auth email confirmation and allowed redirect URLs for the exact live GitHub Pages origin before deployment.
5. Add the public Pages origin(s) to Supabase Auth redirect allow-list; the signup redirect uses `window.location.origin + '/app/index.html'`.
6. Review function owner, `search_path = ''`, function grants, schema grants, RLS enabled on all new tables, and absence of direct client DML grants after migration.
7. Run real PostgREST/RPC negative and positive tests only after explicit migration approval. Required fixtures must use a unique `ZZ_TEST` prefix and fake emails, then be fully removed.
8. No deployment to `main` or GitHub Pages until the test evidence is complete and the owner separately approves release.

## Deliberate limitations
- No existing Auth users are backfilled by the migration. The human-run bootstrap snippet provisions the first Platform Admin and records a bootstrap audit event.
- The draft introduces access control only. It does not invent or migrate player, finance, fixture, welfare, news, or other club operational tables.
- Suspended/revoked users are denied by the access status gate; future protected data/RPCs must also enforce active status on every request.
- Rollback drops all tables and audit/access records created by this migration. This is destructive and must not be run after real access/audit data exists without a reviewed retention/export plan.
- Production fixtures and API tests are **not run** because the migration is unapproved and unapplied. No test result is marked PASS.

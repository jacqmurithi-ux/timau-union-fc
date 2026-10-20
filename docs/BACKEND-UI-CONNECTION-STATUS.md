# Backend and UI connection — review status

## Changes on this branch
- `/app/` becomes an invitation-only Supabase Auth sign-in form.
- The browser uses only the project's public publishable key; no service-role key is present.
- Successful password authentication is not sufficient: the UI also requires an active club_memberships row and at least one unrevoked role_assignments row.
- The dashboard re-checks session, active membership, profile, and roles on direct load; verification errors fail closed and sign out.
- Public self-registration is not implemented. The initial dashboard only verifies account/role and does not claim unbuilt modules are ready.

## Not yet live / blockers
- Production project `owvvimydkjsjlrmnzvdi` currently has no application tables and no recorded migrations. The UI will deny access when membership/role tables are missing.
- The identity schema and privileged invitation workflow are still review-only in PR #7. No production migration has been applied and no Edge Function has been deployed.
- Supabase Auth invitation/redirect settings and real HTTP/PostgREST authorization tests must pass before production use.
- Confirm the `private` schema is excluded from Supabase Data API exposed schemas.
- The pinned ESM CDN import requires network access to `esm.sh`; consider vendoring/bundling if a build pipeline is adopted.

## Release gate
Do not merge this UI or announce private management as live until the reviewed identity schema is approved, deployed via a separately reviewed migration, and real invitation/auth/RLS tests pass. Public website remains on GitHub Pages; no Vercel deployment is introduced.

# Backend and UI connection — review status

## UI changes on the security-review branch
- `/app/` includes sign-in and account creation through Supabase Auth using the public publishable key only.
- Public signup creates an Auth account only. It never creates a club membership, grants a role, or bypasses Chairman approval.
- Sign-in and dashboard load require an active `club_memberships` row and at least one unrevoked `role_assignments` row; errors fail closed.
- No service-role key is included in browser code. Public self-registration does not expose club data.

## Union Test verification
- Union Test (`dzpquzfghapjodmrmavw`) has the Phase 1 identity tables and migration history. The identity tables have RLS enabled.
- Read-only grants/policy inspection shows authenticated SELECT grants only for the identity tables; no anon table grants were found. Private rate-limit counters have a deny-all RLS policy. Service-role grants remain for trusted server-side workflows.
- Security Advisor currently warns that leaked-password protection is disabled. Resolve this in Auth settings before production use.
- HTTP/PostgREST end-to-end tests still require configured test JWT fixtures and must pass; schema inspection alone is not proof of authorization behavior.

## Production release gates
- Production (`owvvimydkjsjlrmnzvdi`) remains unchanged and has no application schema/migrations. No production migration has been applied.
- Review the identity, transactional workflow, rate-limit and auth-user deletion archival SQL drafts together. The identity draft alone explicitly omits trusted lifecycle writes and invitation delivery; do not treat it as a complete backend migration.
- Confirm signup/email-confirmation configuration and redirect allow-list in Supabase Auth. Browser signup will fail if new-user signup is disabled in Auth settings.
- Confirm `private` is not in exposed Data API schemas, run full live PostgREST tests, test invite delivery/reconciliation, and obtain independent review before proposing production migration.
- Public site remains GitHub Pages. No Vercel configuration or deployment is introduced.

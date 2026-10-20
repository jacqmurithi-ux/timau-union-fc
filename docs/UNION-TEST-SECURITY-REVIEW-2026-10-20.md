# Union Test security review — 2026-10-20

## Scope and environment
- Test project: `dzpquzfghapjodmrmavw` (Union Test only).
- Production project `owvvimydkjsjlrmnzvdi` was not modified.
- Public website remains GitHub Pages; no Vercel configuration or deployment.

## Read-only schema review
- Confirmed RLS is enabled on `public.user_profiles`, `public.club_memberships`, `public.role_assignments`, `public.audit_events`, `public.invitation_requests`, and `private.api_rate_limit_counters`.
- Confirmed authenticated grants on identity tables are SELECT-only; no anon table grants were returned by the inspected grant query.
- Confirmed `private.api_rate_limit_counters` has a deny-all policy.
- Confirmed SECURITY DEFINER lifecycle functions inspected use an empty fixed search_path.
- Confirmed `club_admin_*` RPC EXECUTE grants observed only for `postgres` and `service_role`, not `anon` or `authenticated`.
- Current test fixtures remain present. Read-only check found the original active Chairman account still has the active Chairman assignment; no production data was touched.

## Test results and open failures
- Latest GitHub Actions run: https://github.com/jacqmurithi-ux/timau-union-fc/actions/runs/39438261004
- JavaScript smoke-test syntax and Bash harness syntax passed.
- Two-session race test reported one handover success and one denied contender, but the harness then failed while attempting to restore the original Chairman (`chairman_required`). Treat this workflow as FAILED; the restoration path needs correction and another run.
- PostgREST integration test step was skipped by the workflow because the required test HTTP fixtures/JWT secrets were not configured. This is not a pass.
- Security Advisor reports `auth_leaked_password_protection` warning. Enable leaked-password protection in Supabase Auth settings where the plan supports it, then rerun the advisor.

## Signup UI behavior
- Public UI now offers Supabase Auth account creation as well as sign-in.
- Signup creates an Auth account only. It does not create a club membership, assign a role, or grant private access.
- Active membership and an unrevoked role remain mandatory; the UI fails closed.
- Signup delivery requires Supabase Auth "Allow new users to sign up" and the email redirect allow-list to be configured. These project settings and actual email delivery have not been verified from the connector.

## Decision
**Not ready for production migration or launch.** The current identity SQL draft is explicitly not a complete backend by itself; lifecycle workflow, rate-limit, invitation delivery/reconciliation and deletion-archive drafts must be reviewed as one ordered set. Before preparing a production migration for approval:
1. Fix and rerun Chairman race/restore test.
2. Configure test-only JWT fixtures and get the real PostgREST suite to pass (no skipped security tests).
3. Verify signup confirmation/redirect and invitation delivery end to end.
4. Resolve the leaked-password warning or document a plan limitation accepted by the owner.
5. Independently review exact grants, RLS policies, exposed schemas, function ownership, and rollback plan.

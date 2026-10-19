# Private Management Foundation — Status

Last updated: 19 October 2026

## Scope authorised

The project owner authorised implementation of the full private management application, including Supabase authentication, database schema and Row Level Security (RLS). This is a staged implementation; authorisation to build does not mean an unreviewed database migration may be applied to production.

## Current state

- The Phase 1 public club website remains on the approved GitHub Pages path: GitHub `main` → GitHub Pages.
- A starter foundation package has been prepared locally with a basic `/app/` sign-in shell, client configuration placeholders, an initial SQL migration draft, a security smoke-test checklist and next-step notes.
- JavaScript syntax and ZIP archive integrity checks passed for that local package.
- The SQL migration has not been executed or security-tested.
- No Supabase Auth settings, production database, production data or live deployment have been changed.
- The starter package is not a complete private management application and must not be represented as production-ready.

## Security review required before any migration is applied

The initial SQL draft requires review and revision before use. In particular:

- Verify every RLS policy, role helper function, function ownership and `search_path`.
- Enforce announcement approval and publication transitions on the trusted backend; a row-level policy alone must not let contributors self-approve.
- Separate private fixture notes and other sensitive fields from public-safe data paths.
- Define least-privilege access for player private details and audit records.
- Add and test trusted invitation and role-assignment operations. Public self-registration must remain disabled.
- Add automated tests for unauthorised reads/writes, role escalation, approval bypass and direct API access.
- Review each migration before applying it to a test project; do not apply the draft to production.

## Implementation sequence

1. Finalise the role/permission matrix and data classification.
2. Revise the schema and RLS design; provide the SQL for review before applying it.
3. Test migrations and negative access cases in a non-production Supabase project.
4. Implement trusted invitation, role assignment, audit and approval operations.
5. Build private modules incrementally, starting with core club records, then fixtures/training, content workflow, inventory/assets, finance and reports according to the approved permission matrix.
6. Verify the public site remains public-safe and separate from private management.
7. Release through the approved GitHub Pages workflow; do not add Vercel.

## Release gate

Do not claim the private management app is complete until authentication, database policies, role enforcement, critical workflows and negative security tests have passed. Do not apply SQL to production or change production data without presenting the migration for review and receiving approval.

## Repository workflow

This status is being added on a feature branch for review. Merge into `main` only after reviewing the change.

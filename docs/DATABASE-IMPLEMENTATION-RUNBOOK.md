# Timau Union FC — Database Implementation Runbook

**Status: implementation preparation started; production schema changes are not yet authorized for execution.**

Production project reference: `owvvimydkjsjlrmnzvdi`  
Repository: `jacqmurithi-ux/timau-union-fc`  
Hosting: GitHub Pages only; no Vercel.

## Verified baseline (2026-10-20)

- Supabase MCP lists no application tables in `public`.
- Supabase migration history returned no recorded migrations.
- Supabase-managed `auth`, `storage`, `realtime`, and `vault` schemas contain platform-owned objects. Do not alter these platform schemas.
- `supabase/review-drafts/identity_roles_review_draft.sql` exists as a review-only SQL artifact. It is not a migration and must not be run directly in production.
- PR #7 remains draft and unmerged. Its security and live-test blockers remain release blockers.
- Production backup run #39366115632 completed successfully on 2026-10-20. The encrypted artifact `timau-union-production-backup-39366115632-1` exists (artifact ID `12239312757`; expires 2026-11-19). The workflow successfully ran `pg_restore --list` and found 403 archive objects. This validates archive readability/listing, **not** decryption or a real restore. The user has downloaded the artifact; restore rehearsal remains open.

An empty `public` schema is not permission to apply unreviewed SQL. Keep the production database unchanged until the backup gate and review gates below are satisfied.

## Required gates before the first production migration

1. **Backup gate:** an encrypted `.dump.gpg` artifact has been produced and downloaded; `pg_restore --list` passed with 403 archive objects. Still required: decrypt and perform a restore rehearsal in a disposable environment, then validate restored objects. Never commit or share the passphrase. Do not restore into either existing Timau Union Supabase project.
2. **Baseline gate:** read-only production inventory on 2026-10-20 confirmed platform-managed schemas (`auth`, `extensions`, `graphql`, `graphql_public`, `realtime`, `storage`, `vault`) and no tables in `public` or `private`. Complete the remaining inventory of extensions, grants, RLS state, policies, functions, triggers, and Data API exposed schemas before migration. Do not alter platform schemas.
3. **Test environment gate:** a separate Supabase project cannot currently be created because the account is at its two-active-free-project limit. Preserve both `Timau Union FC` production (`owvvimydkjsjlrmnzvdi`) and `Union Test` (`dzpquzfghapjodmrmavw`); do not pause, delete, reset, or restore over either project. First evaluate an isolated ephemeral restore/test environment that cannot write to either project; do not treat `Union Test` as disposable.
4. **Migration review gate:** convert the identity/role review draft into a timestamped migration only after it has been exercised and independently reviewed. Review every privilege, RLS policy, function owner, SECURITY DEFINER function, fixed search_path, trigger, and rollback implication.
5. **Automated verification gate:** run SQL assertions, real HTTP/PostgREST tests with separate anonymous/member/invited/suspended/revoked/Chairman fixtures, invitation provider/recovery tests, and the two-session Chairman handover concurrency harness. A skipped CI step is not a pass.
6. **Human approval gate:** obtain an independent reviewer’s approval and explicit production migration approval. Keep PR #7 draft until all blockers are evidenced.
7. **Production apply gate:** only after gates 1–6, apply one reviewed migration at a time during a controlled window, then run read-only verification and advisors before continuing.

## Implementation sequence

### Phase A — identity and role foundation
- `user_profiles`
- `club_memberships`
- `role_assignments`
- `audit_events`
- private authorization helper functions
- RLS enabled on every exposed application table; deny-by-default grants and policies
- invariant: at most one active Chairman, enforced by a database constraint/index
- no direct client writes to identity/role/audit tables; privileged writes use reviewed trusted workflows only

**Exit:** tests prove no self-assigned roles, no anonymous access to private records, role isolation, correct Chairman handover serialization, and retained audit history.

### Phase B — invitation and identity lifecycle
- invitation/outbox/idempotency and queue claim
- Auth-user creation checkpoint and verified-email activation
- expiry, cancellation, retry/recovery and provider failure handling
- suspension, restoration, revocation and Chairman handover
- rate limits and audit events

**Exit:** real provider and HTTP tests pass; no duplicate or unauthorized activation; stale invitation recovery is documented.

### Phase C — core football operations
- club profile and approved public fields
- player records and optional link to Auth identity
- fixtures, player availability and squad selection
- training sessions and attendance
- transport readiness and support planning

**Exit:** private player and availability data are not exposed publicly; role tests pass.

### Phase D — finance and approvals
- financial categories/accounts and transactions
- evidence and opening-balance requests
- approval decisions and immutable audit trail
- approved-only totals and traceable corrections/reversals

**Exit:** pending/rejected records never affect approved totals; no silent edits or deletions; permissions and separation of duties are tested.

### Phase E — sponsors, welfare, media and store
- sponsor/support records and restricted welfare cases
- draft/approve/publish announcements and media
- merchandise catalogue, variants, orders, payment verification and stock movements

**Exit:** public reads contain only explicitly published fields; customer/payment/welfare data stay private; stock and payment state are auditable.

### Phase F — launch readiness
- RLS and API exposure audit
- security/performance advisors
- backup restore rehearsal and incident runbook
- mobile, low-bandwidth and role-isolation acceptance tests
- club owner sign-off

## Rules

- Never put service-role or secret keys in browser code, GitHub files, issues, logs, or chat.
- Do not expose the `private` schema through the Supabase Data API.
- RLS is mandatory on every table in an exposed schema; authenticated status alone is not authorization.
- Avoid public SECURITY DEFINER functions. Any necessary privileged function must live in a non-exposed schema, check caller identity/authority, use a fixed search_path, and have explicit EXECUTE grants.
- Public website remains static and separate from `/app`; no private records or credentials in public HTML/JavaScript.
- Keep M-Pesa verification manual until a separate integration review is approved; never store PINs or payment credentials.
- All dates/times shown to club users use `Africa/Nairobi`; money uses exact numeric/integer KSh values, never floating point.
- Do not apply a migration directly to production to “see what happens.” Test and verify first.

## Current next action

Next: complete a restore rehearsal without touching either existing Supabase project. The production backup artifact is available at https://github.com/jacqmurithi-ux/union-backup/actions/runs/39366115632/artifacts/12239312757 and expires 2026-11-19. The dump has passed archive-list validation, but decryption/restore is not yet proven. Continue the read-only baseline. Do not begin Phase A migrations until a safe test environment and all review gates are satisfied. No production schema changes have been made by this runbook.

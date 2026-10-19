# Phase 1 invitation delivery recovery runbook — review only

**Scope:** Union Test only until independently reviewed. This runbook does not authorize a production change or Edge Function deployment. Never paste service-role keys, access tokens, refresh tokens, invitation links, or raw provider responses into GitHub, audit metadata, or chat.

## Why reconciliation exists

Supabase Auth delivery and Postgres state updates cannot be one distributed transaction. If Auth creates/sends an invitation and the Edge Function crashes before persisting the Auth user ID, the request may remain in `sending`. The system must not blindly resend: that could create duplicate emails or an ambiguous account state.

## Before acting

1. Confirm the project ref in Supabase Dashboard is exactly `dzpquzfghapjodmrmavw` (Union Test). Stop if any screen or connection indicates production `owvvimydkjsjlrmnzvdi`.
2. Locate the invitation request by its internal request UUID in the dashboard/SQL editor. Confirm state is `sending`, expiry has not passed, and record the request UUID and normalized invited email privately for the incident.
3. Inspect Auth Users and Auth logs for the exact normalized email. Confirm whether an Auth user exists and whether the invite request/delivery succeeded. Never copy email links or tokens into the incident record.
4. Do not automatically retry Auth Admin delivery while the request is in `sending`.

## Recovery A — matching Auth user exists

Use the Supabase SQL editor only in the confirmed Union Test project. Replace placeholders with verified UUIDs; do not commit the resulting query or actual identifiers.

First persist the identity checkpoint and commit it separately:

```sql
select public.club_admin_record_invitation_auth_user(
  '<INVITATION_UUID>'::uuid,
  '<MATCHING_AUTH_USER_UUID>'::uuid
);
```

Then finalize membership/role/audit state:

```sql
select public.club_admin_finish_invitation(
  '<INVITATION_UUID>'::uuid,
  true,
  '<MATCHING_AUTH_USER_UUID>'::uuid,
  null
);
```

The second call must return `sent`. If it fails, preserve the checkpoint and investigate the reported conflict before retrying the database finalization. Do not resend the invitation email. Both functions validate the request state and normalized Auth email; do not bypass those checks or edit tables directly.

## Recovery B — delivery definitely failed and no matching Auth user exists

Only when Auth logs/provider evidence confirm that no matching Auth user was created and delivery failed, mark the claimed request as failed in the SQL editor:

```sql
select public.club_admin_finish_invitation(
  '<INVITATION_UUID>'::uuid,
  false,
  null,
  'auth_invite_failed'
);
```

This is a state transition, not permission to resend immediately. Recheck the request state, expiry, and idempotency key before a Chairman initiates a controlled retry through the reviewed endpoint.

## Stop and escalate

- The email exists in Auth but cannot be confidently matched to the request.
- Provider delivery status is ambiguous.
- Request is no longer `sending`, has expired/cancelled, or already has a different Auth user checkpoint.
- Any function reports an identity/state conflict.
- Project identity is uncertain.

In these cases, do not delete users, edit invitation/membership/role rows directly, resend email, or run production SQL. Preserve only the request UUID, timestamp, bounded error code, and redacted evidence. Escalate for independent review.

## Validation still required before release

- Exercise the actual Edge Function with a successful invite, provider failure, duplicate idempotency key, crash/recovery, and cancellation/expiry.
- Confirm redirect origin is in `ALLOWED_ORIGINS` and Supabase Auth's redirect allowlist.
- Confirm the deployed runtime environment contains correct `SUPABASE_URL`, `SUPABASE_ANON_KEY`, server-only `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_ORIGINS`, and `INVITE_REDIRECT_URL`.
- Verify a rate-limit response returns HTTP 429 and that the Edge Function fails closed with 503 if the rate-limit RPC is unavailable.
- Keep the Edge Function undeployed until independent review approves these checks.

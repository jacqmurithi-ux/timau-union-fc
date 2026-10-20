#!/usr/bin/env bash
# Repeatable two-session Chairman handover race test.
# Requires the reviewed Phase 1 schema/workflow drafts on Union Test only.
set -Eeuo pipefail

EXPECTED_REF="dzpquzfghapjodmrmavw"
: "${SUPABASE_TEST_DB_URL:?Set a disposable Union Test PostgreSQL connection URL}"
: "${SUPABASE_TEST_PROJECT_REF:?Set SUPABASE_TEST_PROJECT_REF explicitly}"
if [[ "$SUPABASE_TEST_PROJECT_REF" != "$EXPECTED_REF" || "$SUPABASE_TEST_DB_URL" != *"$EXPECTED_REF"* ]]; then
  echo "Refusing to run: connection must identify Union Test ($EXPECTED_REF)." >&2
  exit 2
fi
command -v psql >/dev/null || { echo "psql is required" >&2; exit 2; }

psqlq() { psql "$SUPABASE_TEST_DB_URL" -X -v ON_ERROR_STOP=1 "$@"; }
sql() { psqlq -Atqc "$1"; }
new_uuid() { cat /proc/sys/kernel/random/uuid; }

active_chair_count="$(sql "select count(*) from public.role_assignments where role_key='chairman' and revoked_at is null")"
if [[ "$active_chair_count" -gt 1 ]]; then
  echo "FAIL: more than one active Chairman exists before test; refusing to proceed." >&2
  exit 1
fi
original_chair="$(sql "select m.user_id from public.role_assignments r join public.club_memberships m on m.id=r.membership_id where r.role_key='chairman' and r.revoked_at is null and m.status='active' limit 1")"
chair="$(if [[ -n "$original_chair" ]]; then printf '%s' "$original_chair"; else new_uuid; fi)"
successor_a="$(new_uuid)"
successor_b="$(new_uuid)"
email_chair="phase1-race-chair-$chair@timau-test.invalid"
email_a="phase1-race-a-$successor_a@timau-test.invalid"
email_b="phase1-race-b-$successor_b@timau-test.invalid"
setup_started=0

cleanup() {
  local current_chair restore_status
  [[ "$setup_started" == 1 ]] || return 0
  current_chair="$(sql "select m.user_id from public.role_assignments r join public.club_memberships m on m.id=r.membership_id where r.role_key='chairman' and r.revoked_at is null and m.status='active' limit 1" 2>/dev/null || true)"
  if [[ -n "$original_chair" && -n "$current_chair" && "$current_chair" != "$original_chair" ]]; then
    set +e
    psqlq -Atqc "select public.club_admin_handover_chairman('$current_chair'::uuid,'$original_chair'::uuid,'restore original Chairman after test')" >/dev/null 2>&1
    restore_status=$?
    set -e
    current_chair="$(sql "select m.user_id from public.role_assignments r join public.club_memberships m on m.id=r.membership_id where r.role_key='chairman' and r.revoked_at is null and m.status='active' limit 1" 2>/dev/null || true)"
    if [[ "$restore_status" -ne 0 || "$current_chair" != "$original_chair" ]]; then
      echo "WARNING: could not restore the original Chairman. Preserving test fixture records to avoid deleting the only active Chairman." >&2
      return 0
    fi
  fi
  # If there was no Chairman before the test, these fixtures are disposable and can be removed.
  # If there was one, restore it before deleting the temporary successors.
  if [[ -n "$original_chair" && "$current_chair" != "$original_chair" ]]; then
    echo "WARNING: preserving fixtures because original Chairman restoration is unverified." >&2
    return 0
  fi
  psqlq -c "delete from public.audit_events where actor_user_id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid);
    delete from public.role_assignments where membership_id in (select id from public.club_memberships where user_id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid));
    delete from public.user_profiles where user_id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid);
    delete from public.club_memberships where user_id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid);
    delete from auth.users where id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid);
    delete from private.api_rate_limit_counters where actor_user_id in ('$chair'::uuid,'$successor_a'::uuid,'$successor_b'::uuid);" >/dev/null
}
trap cleanup EXIT

setup_started=1
if [[ -z "$original_chair" ]]; then
  psqlq -c "insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
    values ('$chair'::uuid,'authenticated','authenticated','$email_chair',clock_timestamp(),jsonb_build_object('provider','email','providers',jsonb_build_array('email')),'{}'::jsonb,clock_timestamp(),clock_timestamp());" >/dev/null
fi
psqlq -c "insert into auth.users(id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values
  ('$successor_a'::uuid,'authenticated','authenticated','$email_a',clock_timestamp(),jsonb_build_object('provider','email','providers',jsonb_build_array('email')),'{}'::jsonb,clock_timestamp(),clock_timestamp()),
  ('$successor_b'::uuid,'authenticated','authenticated','$email_b',clock_timestamp(),jsonb_build_object('provider','email','providers',jsonb_build_array('email')),'{}'::jsonb,clock_timestamp(),clock_timestamp());
  insert into public.club_memberships(user_id,status,invited_email,invited_by,activated_at)
  values
  ('$successor_a'::uuid,'active','$email_a','$chair'::uuid,clock_timestamp()),
  ('$successor_b'::uuid,'active','$email_b','$chair'::uuid,clock_timestamp());
  insert into public.role_assignments(membership_id,role_key,assigned_by)
  select id,'treasurer','$chair'::uuid from public.club_memberships where user_id='$successor_a'::uuid;
  insert into public.role_assignments(membership_id,role_key,assigned_by)
  select id,'secretary','$chair'::uuid from public.club_memberships where user_id='$successor_b'::uuid;" >/dev/null
if [[ -z "$original_chair" ]]; then
  psqlq -c "insert into public.club_memberships(user_id,status,invited_email,invited_by,activated_at)
    values ('$chair'::uuid,'active','$email_chair','$chair'::uuid,clock_timestamp());
    insert into public.role_assignments(membership_id,role_key,assigned_by)
    select id,'chairman','$chair'::uuid from public.club_memberships where user_id='$chair'::uuid;" >/dev/null
fi

# Launch independent psql processes so each RPC runs in its own database session.
psqlq -Atqc "select public.club_admin_handover_chairman('$chair'::uuid,'$successor_a'::uuid,'multi-session race test A')" >/tmp/phase1-handover-a.out 2>/tmp/phase1-handover-a.err &
pid_a=$!
psqlq -Atqc "select public.club_admin_handover_chairman('$chair'::uuid,'$successor_b'::uuid,'multi-session race test B')" >/tmp/phase1-handover-b.out 2>/tmp/phase1-handover-b.err &
pid_b=$!
set +e
wait "$pid_a"; status_a=$?
wait "$pid_b"; status_b=$?
set -e

if [[ "$status_a" -eq 0 && "$status_b" -ne 0 ]]; then
  winner="$successor_a"; loser_error="/tmp/phase1-handover-b.err"
elif [[ "$status_b" -eq 0 && "$status_a" -ne 0 ]]; then
  winner="$successor_b"; loser_error="/tmp/phase1-handover-a.err"
else
  echo "FAIL: expected exactly one successful handover and one denied concurrent request." >&2
  cat /tmp/phase1-handover-a.err /tmp/phase1-handover-b.err >&2
  exit 1
fi
if ! grep -q "chairman_required" "$loser_error"; then
  echo "FAIL: losing request was not denied because the original Chairman authority was no longer active." >&2
  cat "$loser_error" >&2
  exit 1
fi

active_count="$(sql "select count(*) from public.role_assignments where role_key='chairman' and revoked_at is null")"
active_user="$(sql "select m.user_id from public.role_assignments r join public.club_memberships m on m.id=r.membership_id where r.role_key='chairman' and r.revoked_at is null and m.status='active' limit 1")"
if [[ "$active_count" != 1 || "$active_user" != "$winner" ]]; then
  echo "FAIL: expected exactly one active Chairman and the winner to hold the role; count=$active_count user=$active_user" >&2
  exit 1
fi
echo "PASS: two independent database sessions raced; one handover succeeded, the other was denied, and exactly one active Chairman remained."

# Restore the pre-test Chairman if one existed. The EXIT trap verifies restoration before cleanup.
if [[ -n "$original_chair" ]]; then
  psqlq -Atqc "select public.club_admin_handover_chairman('$winner'::uuid,'$original_chair'::uuid,'restore original Chairman after concurrency test')" >/dev/null
  restored="$(sql "select count(*) from public.role_assignments r join public.club_memberships m on m.id=r.membership_id where r.role_key='chairman' and r.revoked_at is null and m.status='active' and m.user_id='$original_chair'::uuid")"
  [[ "$restored" == 1 ]] || { echo "FAIL: original Chairman restoration did not verify." >&2; exit 1; }
  echo "PASS: original Chairman fixture restored."
fi

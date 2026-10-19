#!/usr/bin/env node
/**
 * Phase 1 PostgREST security smoke tests.
 *
 * Requires disposable Union Test fixtures and user-issued JWTs in environment.
 * Never run with production URL or production credentials.
 *
 * Required environment:
 *   SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY
 *   SUPABASE_TEST_MEMBER_JWT, SUPABASE_TEST_MEMBER_USER_ID
 *   SUPABASE_TEST_INVITED_JWT, SUPABASE_TEST_INVITED_USER_ID
 *   SUPABASE_TEST_SUSPENDED_JWT, SUPABASE_TEST_SUSPENDED_USER_ID
 *   SUPABASE_TEST_REVOKED_JWT, SUPABASE_TEST_REVOKED_USER_ID
 *   SUPABASE_TEST_CHAIRMAN_JWT
 *
 * Run: node tests/phase-1-postgrest-smoke.mjs
 * This script performs reads and a DELETE against an impossible sentinel UUID only.
 */

import assert from "node:assert/strict";

const url = (process.env.SUPABASE_TEST_URL ?? "").replace(/\/$/, "");
const anonKey = process.env.SUPABASE_TEST_ANON_KEY ?? "";
const fixtures = {
  member: { jwt: process.env.SUPABASE_TEST_MEMBER_JWT ?? "", id: process.env.SUPABASE_TEST_MEMBER_USER_ID ?? "" },
  invited: { jwt: process.env.SUPABASE_TEST_INVITED_JWT ?? "", id: process.env.SUPABASE_TEST_INVITED_USER_ID ?? "" },
  suspended: { jwt: process.env.SUPABASE_TEST_SUSPENDED_JWT ?? "", id: process.env.SUPABASE_TEST_SUSPENDED_USER_ID ?? "" },
  revoked: { jwt: process.env.SUPABASE_TEST_REVOKED_JWT ?? "", id: process.env.SUPABASE_TEST_REVOKED_USER_ID ?? "" },
  chairman: { jwt: process.env.SUPABASE_TEST_CHAIRMAN_JWT ?? "", id: "" },
};
const required = [
  ["SUPABASE_TEST_URL", url], ["SUPABASE_TEST_ANON_KEY", anonKey],
  ...Object.entries(fixtures).flatMap(([name, f]) => [[`SUPABASE_TEST_${name.toUpperCase()}_JWT`, f.jwt], ...(name === "chairman" ? [] : [[`SUPABASE_TEST_${name.toUpperCase()}_USER_ID`, f.id]])]),
];
const missing = required.filter(([, value]) => !value).map(([name]) => name);
if (missing.length) {
  console.error("Missing test-only environment variables:", missing.join(", "));
  process.exit(2);
}
assert.match(url, /^https:\/\/[^/]+\.supabase\.co$/i, "URL must be a Supabase HTTPS project URL");
assert.ok(!url.includes("owvvimydkjsjlrmnzvdi"), "Production project is forbidden for this test script");
assert.ok(!url.includes("chamalive"), "Wrong project supplied");

const endpoint = (table, query = "select=user_id") => `${url}/rest/v1/${table}?${query}`;
async function request({ path, jwt = anonKey, method = "GET", body }) {
  const headers = { apikey: anonKey, Authorization: `Bearer ${jwt}`, Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (method === "DELETE") headers.Prefer = "return=minimal";
  const response = await fetch(path, { method, headers, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { /* response may be plain text */ }
  return { status: response.status, ok: response.ok, data, text };
}
function expectDenied(label, response) {
  assert.ok(!response.ok, `${label}: expected HTTP denial, got ${response.status} ${response.text}`);
  console.log(`PASS ${label}: denied with HTTP ${response.status}`);
}
async function readProfile(label, fixture, expectedOwnRow) {
  const response = await request({ path: endpoint("user_profiles"), jwt: fixture.jwt });
  if (!response.ok) {
    if (expectedOwnRow) throw new Error(`${label}: active identity could not read own profile: HTTP ${response.status} ${response.text}`);
    console.log(`PASS ${label}: protected profile read denied with HTTP ${response.status}`);
    return;
  }
  assert.ok(Array.isArray(response.data), `${label}: expected array response`);
  if (expectedOwnRow) {
    assert.ok(response.data.some(row => row.user_id === fixture.id), `${label}: expected own profile fixture missing`);
    assert.ok(response.data.every(row => row.user_id === fixture.id), `${label}: profile read leaked another user's row`);
    console.log(`PASS ${label}: reads own profile only`);
  } else {
    assert.equal(response.data.length, 0, `${label}: RLS leaked ${response.data.length} profile rows`);
    console.log(`PASS ${label}: RLS returned no profile rows`);
  }
}

const anonRead = await request({ path: endpoint("user_profiles") });
expectDenied("anonymous SELECT on user_profiles", anonRead);

await readProfile("active member", fixtures.member, true);
await readProfile("invited identity", fixtures.invited, false);
await readProfile("suspended identity with existing JWT", fixtures.suspended, false);
await readProfile("revoked identity with existing JWT", fixtures.revoked, false);

const chairmanRead = await request({ path: endpoint("user_profiles"), jwt: fixtures.chairman.jwt });
assert.ok(chairmanRead.ok, `Chairman authorized read failed: HTTP ${chairmanRead.status} ${chairmanRead.text}`);
assert.ok(Array.isArray(chairmanRead.data), "Chairman response should be a row array");
for (const name of ["member", "suspended", "revoked"]) {
  assert.ok(chairmanRead.data.some(row => row.user_id === fixtures[name].id), `Chairman cannot read expected authorized fixture: ${name}`);
}
console.log("PASS Chairman can read the seeded authorized profile fixtures");
const chairmanAudit = await request({ path: endpoint("audit_events", "select=id&limit=1"), jwt: fixtures.chairman.jwt });
assert.ok(chairmanAudit.ok, `Chairman audit read failed: HTTP ${chairmanAudit.status} ${chairmanAudit.text}`);
console.log("PASS Chairman audit endpoint is authorized");

const sentinel = "00000000-0000-4000-8000-000000000099";
const memberDelete = await request({
  path: endpoint("user_profiles", `user_id=eq.${sentinel}`),
  jwt: fixtures.member.jwt,
  method: "DELETE",
});
expectDenied("authenticated member direct DELETE (sentinel UUID only)", memberDelete);

const anonRpc = await request({
  path: `${url}/rest/v1/rpc/club_admin_begin_invitation`,
  method: "POST",
  body: { _actor: fixtures.chairman.id || sentinel, _email: "phase1-denial@example.invalid", _role_key: "secretary", _request_key: sentinel },
});
expectDenied("anonymous privileged RPC invocation", anonRpc);

const memberRpc = await request({
  path: `${url}/rest/v1/rpc/club_admin_begin_invitation`,
  jwt: fixtures.member.jwt,
  method: "POST",
  body: { _actor: fixtures.member.id, _email: "phase1-denial@example.invalid", _role_key: "secretary", _request_key: sentinel },
});
expectDenied("authenticated member privileged RPC invocation", memberRpc);

console.log("ALL POSTGREST SMOKE TESTS PASSED. These tests do not exercise Auth Admin email delivery or Edge Function configuration.");

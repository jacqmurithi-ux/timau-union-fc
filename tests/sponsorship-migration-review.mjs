import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const sql = readFileSync("supabase/migrations/20261025000000_public_sponsorship.sql", "utf8");
const checks = [
  ["enquiry RLS enabled", /alter table public\.sponsor_enquiries enable row level security/i.test(sql)],
  ["public settings RLS enabled", /alter table public\.sponsor_public_settings enable row level security/i.test(sql)],
  ["unauthenticated table grants revoked", /revoke all on public\.sponsor_enquiries from anon,authenticated/i.test(sql)],
  ["only narrow enquiry updates granted", /grant update\(status,contacted_at\) on public\.sponsor_enquiries to authenticated/i.test(sql)],
  ["per-email rate limiting is server-side", /pg_advisory_xact_lock[\s\S]*?interval '15 minutes'/i.test(sql)],
  ["public settings direct grants revoked", /revoke all on public\.sponsor_public_settings from public,anon,authenticated/i.test(sql)],
  ["existing validator not replaced", !/create or replace function private\.valid_club_record_data/i.test(sql)],
  ["no destructive table or column drops", !/\bdrop\s+table\b|\bdrop\s+column\b/i.test(sql)]
];
for (const [label, ok] of checks) {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}`);
  assert.ok(ok, label);
}

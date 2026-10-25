import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const sql = readFileSync("supabase/migrations/20261025000000_public_sponsorship.sql", "utf8");
const checks = [
  ["enquiry RLS enabled", /alter table public\.sponsor_enquiries enable row level security/i.test(sql)],
  ["public settings RLS enabled", /alter table public\.sponsor_public_settings enable row level security/i.test(sql)],
  ["unauthenticated table grants revoked", /revoke all on public\.sponsor_enquiries from anon,authenticated/i.test(sql)],
  ["direct enquiry updates are not granted", /revoke update,insert,delete on public\.sponsor_enquiries from authenticated/i.test(sql)],
  ["enquiry status changes use an audited role-checked RPC", /create or replace function public\.sponsor_enquiry_set_status[\s\S]*?sponsor_workspace_audit[\s\S]*?grant execute on function public\.sponsor_enquiry_set_status\(uuid,text,text,uuid\) to authenticated/i.test(sql)],
  ["per-email rate limiting is server-side", /pg_advisory_xact_lock[\s\S]*?interval '15 minutes'/i.test(sql)],
  ["public settings direct grants revoked", /revoke all on public\.sponsor_public_settings from public,anon,authenticated/i.test(sql)],
  ["public description never falls back to internal record details", !/coalesce\(nullif\(s\.public_description,\x27\x27\),c\.data->>\x27details\x27\)/i.test(sql)],
  ["public display settings are audit logged", /sponsor_public_settings_updated/i.test(sql)],
  ["existing validator not replaced", !/create or replace function private\.valid_club_record_data/i.test(sql)],
  ["no destructive table or column drops", !/\bdrop\s+table\b|\bdrop\s+column\b/i.test(sql)]
];
for (const [label, ok] of checks) {
  console.log(`${ok ? "PASS" : "FAIL"} ${label}`);
  assert.ok(ok, label);
}

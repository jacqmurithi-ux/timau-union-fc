import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const path = "supabase/migrations/20261025070000_finance_approval_hardening.sql";
const sql = readFileSync(path, "utf8");
const checks = [
  ["transactional migration", /\bbegin;[\s\S]*\bcommit;\s*$/i.test(sql)],
  ["SECURITY DEFINER function uses empty search_path", /security definer\s+set search_path=''/i.test(sql)],
  ["Platform Admin denial is before club role allow-list", /if private\.is_active_platform_admin\(auth\.uid\(\)\) then[\s\S]*?raise exception 'Platform Admin cannot approve or reject club expenses'[\s\S]*?r:=private\.current_club_roles\(\);[\s\S]*?array\['chairman','secretary','treasurer'\]/i.test(sql)],
  ["self-approval is denied", /oldrow\.created_by=auth\.uid\(\)[\s\S]*?raise exception 'You cannot approve or reject your own expense'/i.test(sql)],
  ["only pending expenses can be reviewed", /oldrow\.status<>'pending'[\s\S]*?raise exception 'Only pending expenses can be reviewed'/i.test(sql)],
  ["decision and reason are validated", /_decision not in \('approved','rejected'\)[\s\S]*?length\(btrim\(_reason\)\)<3[\s\S]*?length\(_reason\)>1000/i.test(sql)],
  ["approval ledger entry is created only for approval", /if _decision='approved' then[\s\S]*?insert into private\.club_financial_ledger[\s\S]*?else[\s\S]*?status='rejected'/i.test(sql)],
  ["audit stores old and new status and marks no admin override", /old_data,new_data,old_status,new_status,is_admin_override,reason[\s\S]*?oldrow\.status,_decision,false,btrim\(_reason\)/i.test(sql)],
  ["public and anonymous execution revoked", /revoke all on function public\.tm_review_expense\(uuid,text,text\) from public,anon/i.test(sql)],
  ["authenticated execution explicitly granted", /grant execute on function public\.tm_review_expense\(uuid,text,text\) to authenticated/i.test(sql)],
  ["migration does not alter table rows or permissions outside the RPC", !/\b(drop table|alter table|create policy)\b/i.test(sql)]
];

let failed = 0;
for (const [name, ok] of checks) {
  console.log(`${ok ? "PASS" : "FAIL"}: ${name}`);
  if (!ok) failed++;
}
if (failed) process.exit(1);
console.log(`Passed ${checks.length} finance migration static checks.`);

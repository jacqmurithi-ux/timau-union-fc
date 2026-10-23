# Monthly Sponsor Report — Test Checklist

Run this checklist against a schema-matched non-production Supabase project after applying the report-only migration. Do not create sample rows in production.

## Before testing
- [ ] Review `supabase/migrations/20261023160000_monthly_sponsor_report.sql` before applying it.
- [ ] Confirm the target database has `private.club_records`, `private.sponsor_user_links`, attendance and social tables, and the role helper functions used by the report RPCs.
- [ ] The current **Union Test** project does not yet match this schema (including missing `public.kit_items`, `public.kit_managers`, `private.sponsor_user_links`, `private.home_attendance_monthly` and helper functions). Do not apply the migration there until a schema-matched non-production database is available.
- [ ] Apply only the report migration to a schema-matched non-production project. It should create the private monthly report table and report RPCs; it must not alter Kit inventory or Kit permissions.
- [ ] Use separate test accounts for Chairman, Treasurer, Secretary, Sponsor A, Sponsor B and Coach-only roles.

## Chairman / Admin
- [ ] Open **Monthly sponsor report** from the shared workspace tab row.
- [ ] Select a month and confirm attendance, social metrics and results render without demo values. No Kit summary appears in the report.
- [ ] Edit up to three highlights, save draft, refresh and confirm they persist.
- [ ] Confirm the status flow is Draft → Approved → Published.
- [ ] Confirm publishing a draft directly is rejected; it must be approved first.
- [ ] Confirm publication is blocked until all three non-blank highlights are saved.
- [ ] Confirm an approved/published report remains a saved snapshot if source records change.
- [ ] Print and choose Save as PDF; export CSV and inspect downloaded rows for report, summary, social and highlights only.

## Treasurer
- [ ] Confirm the Treasurer can save a report draft but cannot approve or publish it.
- [ ] Confirm report changes do not alter Kit records or permissions.

## Secretary
- [ ] Confirm the Secretary can prepare/save a draft but cannot approve or publish it.
- [ ] Confirm the report does not reveal internal sponsor notes.

## Sponsor A and Sponsor B
- [ ] Before publication, open the selected month and confirm no draft or approved report content is shown.
- [ ] After publication, confirm each sponsor sees only the published club summary, highlights, results and sponsor-tagged posts permitted for that sponsor.
- [ ] Inspect `monthly_sponsor_report_get`: sponsor payload must not contain other sponsors' rows, IDs or amounts, internal notes, or unpublished content.
- [ ] Confirm no Kit funding, inventory, first-aid, or Kit-needs data is displayed in the Monthly Sponsor Report.

## Coach-only account (no report access)
- [ ] Confirm the shared navigation does not show Monthly sponsor report.
- [ ] Enter the report URL directly; expect an authorization error/denied view.
- [ ] Call `monthly_sponsor_report_get`, `monthly_sponsor_report_save`, and `monthly_sponsor_report_set_status` through the authenticated client; expect authorization denial.

## Data integrity and regression checks
- [ ] Confirm migration creates no sponsor reports or sample rows.
- [ ] Confirm existing Kit inventory, movement history, Kit module, first-aid contents, attendance and social stats remain untouched by this report-only change.
- [ ] Confirm unknown report-data keys are rejected and highlights are limited to three entries of at most 500 characters.
- [ ] Confirm no direct table grants were added for the private monthly report table; access is through the scoped RPCs.

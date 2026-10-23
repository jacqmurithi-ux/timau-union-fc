# Monthly Sponsor Report — Test Checklist

Run this checklist against a non-production Supabase project after applying the migration there. Do not create sample rows in production.

## Before testing
- [ ] Review `supabase/migrations/20261023160000_monthly_sponsor_report_kit_funding.sql` before applying it.
- [ ] Confirm the target database has the existing `private.club_records` sponsor records and existing role helper functions.
- [ ] Apply the migration in the test project only, then verify the four new `kit_items` columns and constraints.
- [ ] Use separate test accounts for Chairman, Treasurer, Secretary, Sponsor A, Sponsor B and Coach-only roles.

## Chairman / Admin
- [ ] Open **Monthly sponsor report** from the shared workspace tab row.
- [ ] Select a month and confirm attendance, social metrics, kit condition/needs and results render without demo values.
- [ ] Edit up to three highlights, save draft, refresh and confirm they persist.
- [ ] Confirm the status flow is Draft → Approved → Published.
- [ ] Confirm publishing a draft directly is rejected; it must be approved first.
- [ ] Confirm publication is blocked until all three non-blank highlights are saved.
- [ ] Confirm an approved/published report remains a saved snapshot if source records change.
- [ ] Print and choose Save as PDF; export CSV and inspect the downloaded rows.

## Treasurer
- [ ] Add/edit a kit item and record acquisition type, acquisition date, sponsor and optional amount.
- [ ] Confirm negative amounts are rejected and existing kit items with blank funding fields still save.
- [ ] Confirm Treasurer can save a report draft but cannot approve or publish it.
- [ ] Confirm the Treasurer can change only funding metadata through the narrow `kit_set_sponsor_funding` RPC, while ordinary direct inventory updates remain governed by the existing kit RLS policies.

## Secretary
- [ ] Confirm sponsor funding fields are enabled and persist.
- [ ] Confirm the Secretary can prepare/save a draft but cannot approve or publish it.
- [ ] Confirm the report does not reveal internal sponsor notes.

## Sponsor A and Sponsor B
- [ ] Before publication, open the selected month and confirm no draft or approved report content is shown.
- [ ] After publication, confirm each sponsor sees the club summary, highlights, results, kit needs and sponsor-tagged posts in the published snapshot.
- [ ] Record kit funded by Sponsor A and Sponsor B in the test project; sign in as each sponsor and confirm each sees only their own kit items, quantities, dates, conditions and funding amounts.
- [ ] Inspect the response to `monthly_sponsor_report_get`: sponsor payload must not contain other sponsors' rows, IDs or amounts, internal notes, or unpublished content.
- [ ] Confirm the empty state reads **No kit funded by this sponsor yet** where appropriate.

## Coach-only account (no report access)
- [ ] Confirm the shared navigation does not show Monthly sponsor report.
- [ ] Enter the report URL directly; expect an authorization error/denied view.
- [ ] Call `monthly_sponsor_report_get`, `monthly_sponsor_report_save`, and `monthly_sponsor_report_set_status` through the authenticated client; expect authorization denial.
- [ ] Attempt to change `funded_by_sponsor_id`, `funding_amount`, or set `acquisition_type = 'sponsor-funded'`; expect the database trigger to reject it.

## Data integrity and regression checks
- [ ] Confirm migration creates no sponsor reports or sample kit rows.
- [ ] Confirm the existing kit inventory, movement history, first-aid contents, attendance and social stats still load.
- [ ] Confirm sponsor funding is only attached to a record whose `private.club_records.record_type = 'sponsor'`.
- [ ] Confirm unknown report-data keys are rejected and highlights are limited to three entries of at most 500 characters.
- [ ] Confirm no direct table grants were added for the private monthly report table; access is through the scoped RPCs.

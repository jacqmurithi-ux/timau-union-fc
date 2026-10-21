# Coach dashboard test checklist

Run against a disposable Supabase project before applying `20261022100000_coach_dashboard.sql` to production.

## Role and record isolation
- [ ] Coach can open `/app/coach.html`; an account without Coach, Chairman, or Platform Admin access is denied.
- [ ] Coach can view fixtures, activities and the read-only squad list.
- [ ] Coach cannot add, edit, approve, archive or return player records to draft.
- [ ] Coach sees only the allowlisted injury/fitness and discipline summary fields; restricted welfare notes and contact details are never returned.
- [ ] Coach can create and edit their own training plans, attendance, match selection drafts, tactics, performance, match analysis and development records.
- [ ] Coach cannot edit a different Coach's record.
- [ ] Team Manager and other non-Coach roles cannot create or edit Coach records, even by calling RPCs directly.
- [ ] Coach role cannot access News, Sponsors, finance, or transport/ fares through this dashboard or its database functions.
- [ ] Direct table access to `private.coach_records` and `private.tm_record_audit` is denied to anon/authenticated roles.

## Approval and overrides
- [ ] Every new Coach record is saved with `publication_status='draft'`.
- [ ] Editing an approved Coach record returns it to draft and clears approval metadata.
- [ ] Coach cannot approve, archive or publish Coach records.
- [ ] Chairman and active Platform Admin can view/edit Coach records across owners.
- [ ] An administrator override requires a reason and writes actor, timestamp, record id, old/new data, old/new status, action and override flag to the existing `private.tm_record_audit` table.
- [ ] Chairman/Admin approval or status changes are also audited.
- [ ] Team Manager remains responsible for submitting the official team sheet; Coach match selection is only a draft.

## Existing-data caveat
The dashboard intentionally does not derive availability or fitness from free-text TM welfare notes. It only displays explicitly structured `availability_status`, `fitness_status`, `return_status`, and discipline-summary fields if present. The current TM form schema may need a separate reviewed change to collect those structured fields; do not infer them or publish private notes.

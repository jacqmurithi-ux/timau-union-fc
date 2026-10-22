# Kit & Equipment Manager — acceptance test checklist

## Deployment order
1. Review `supabase/migrations/20261022290000_kit_equipment_manager.sql`.
2. Apply it to the intended Supabase project using the normal reviewed migration process; this PR does not seed data or apply the migration to production.
3. Merge the code and let GitHub Pages publish from `main`.
4. Confirm the page loads at `/app/kit.html` after signing in.

## Test roles
- **Secretary:** create/edit inventory, assign a custodian, record a movement, add first-aid contents, export CSV. Cannot assign/remove kit managers unless also Admin/Chairman.
- **Team Manager:** same inventory management actions; cannot manage kit managers unless also Admin/Chairman.
- **Captain assigned as kit manager:** after Admin/Chairman adds the member in Kit managers, can create/edit kit and log movements. Removing the assignment must remove management access without changing the member's role.
- **Custodian:** can read inventory and update status/usable/damaged/missing quantities only for items assigned to them; cannot change total, name/category, or custodian assignment.
- **Coach:** can record issue/return/lost/damaged/repaired movements, run training and fixture checklists, update status and usable/damaged/missing quantities, and reduce first-aid current quantity. Verify the audit trail records actor and timestamp. Coach must be blocked from changing total, item identity, custodian, adding/removing kit managers, deleting inventory, changing first-aid requirements/expiry, or increasing first-aid stock.
- **Treasurer:** can view inventory, first-aid status, managers/custodians and movement history; attempt insert/update/delete and confirm RLS denies writes.
- **Sponsor Lead / Media Team:** read-only; verify no write controls or database writes.
- **Anonymous/public:** no access to any kit table or page data.

## Functional tests
1. Empty database shows “No kit recorded yet”; no demo rows are inserted.
2. Create a red jersey row with total 18, usable 16, damaged 1, missing 1. Summary and row show correct counts and colour.
3. Try total 10, usable 8, damaged 2, missing 1; UI and database must reject it.
4. Separate match-day and training balls using the Use field and filter.
5. Record a lost/damaged movement and verify inventory, movement history, attention summary and alert.
6. Create a first-aid kit with bandages/gloves/ice packs. Set current below required; status changes to “Missing items”. Set an expiry date in the past; expired alert appears.
7. Coach uses two bandages; current quantity falls by two and movement audit has the coach identity and timestamp.
8. Choose a home fixture, tick equipment taken, record return; check movements include fixture/date/notes. Repeat for training without fixture.
9. Export CSV and check current filters are respected.
10. Verify no user can delete kit items or edit movement history.

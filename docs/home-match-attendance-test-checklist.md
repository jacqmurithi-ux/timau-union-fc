# Home match attendance — verification checklist

No sample attendance records are seeded. The new table must remain empty until an authorised official records a real attendance count.

## Database migration
- Review and apply `supabase/migrations/20261022280000_home_match_attendance.sql` only after confirming the fixture JSON keys match the current fixture workflow.
- Confirm `match_attendance` has a unique fixture reference, non-negative count check, and RLS enabled.
- Confirm the trigger rejects away fixtures and non-completed fixtures.
- Confirm direct access to raw records is denied to sponsors and anonymous/public users.
- Confirm `public.home_attendance_monthly` is not directly selectable by all authenticated users; reports are served through role-checked RPCs.
- Confirm the sponsor RPC returns only monthly average, season average, and the last five matches' date/opponent/competition/count (no notes or recorder identity).

## Secretary
1. Sign in with a Secretary account and open the Secretary workspace.
2. Create or open a completed fixture, mark `Home or away = home` and `Match status = completed`.
3. Record attendance (including zero as a valid count), add optional notes, then refresh.
4. Confirm the count persists and can be edited; confirm updated_at changes.
5. Confirm completed home fixtures without a count show **MISSING ATTENDANCE**.
6. Confirm away, scheduled, postponed, and cancelled fixtures do not offer attendance entry.

## Team Manager
1. Sign in with Team Manager and open the club workspace.
2. Confirm the same completed-home-fixture attendance entry and report link are available.
3. Confirm Team Manager cannot bypass server-side validation by attempting to record an away fixture.

## Treasurer (read-only)
1. Sign in as Treasurer and open Home attendance.
2. Confirm the report is readable and CSV export works.
3. Confirm an attempt to insert or update `match_attendance` is denied by RLS.

## Sponsor (summary only)
1. Sign in using a sponsor account linked to an approved sponsor record.
2. Open My partnership and confirm the read-only attendance card shows this month's average, season average, and the last five recorded home matches.
3. Confirm match notes, recorder identity, and raw table records are not visible or directly accessible.
4. When no counts exist, confirm the card says **No attendance recorded yet** and does not invent figures.

## Report page
- Open `/app/home-attendance.html` on mobile and desktop.
- Check month filter, monthly table, season average, match bars, CSV export and empty states.
- Verify only completed home fixtures are included.

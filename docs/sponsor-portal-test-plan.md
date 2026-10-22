# Sponsor portal verification checklist

Run this checklist after applying the Sponsor Portal migrations to an isolated database with two approved sponsor accounts (A and B), two approved sponsor records, and linked agreements/contributions/media. Do not mark the portal production-ready until every security case passes.

## Routing and unlinked accounts
- [ ] Sign in as a user whose only active role is `sponsor`; `app/workspace.html` redirects to `app/sponsor.html`.
- [ ] Directly call `public.club_get_workspace_bundle()` as that sponsor. `records` and `tm_records` are empty; no player rows or fields are returned.
- [ ] Query private player/club records directly as `authenticated`. Access is denied by table grants/RLS.
- [ ] Sign in as a Sponsor user without an active row in `private.sponsor_user_links`. Only the not-linked message is shown; the portal tabs and sponsor data remain hidden.

## Isolation (must test direct RPC calls, not only the UI)
- [ ] Link Sponsor A user to Sponsor A record and Sponsor B user to Sponsor B record.
- [ ] As Sponsor A, call `public.sponsor_portal_get()`. Agreements, contributions, benefits, requests, profile drafts, media and signed-file access contain only Sponsor A data.
- [ ] Attempt to query `private.sponsor_agreements`, `private.sponsor_contributions`, `private.sponsor_user_links`, `private.sponsor_profile_edits`, `private.sponsor_media_shares` directly as Sponsor A. Direct access is denied.
- [ ] Try to submit a request or save details while unlinked; both RPCs reject the call.
- [ ] Try to pass another sponsor ID to portal request/detail RPCs. The RPC signatures accept no client-supplied sponsor ID and derive ownership from the active link.

## Sponsor Lead and audit
- [ ] A Sponsor Lead can link, change and unlink an approved Sponsor account to an approved sponsor record. Each operation adds an audit row with actor, timestamp, record, before/after data and reason.
- [ ] A non-Sponsor Lead, non-Platform Admin account cannot link/unlink or approve profile edits.
- [ ] A sponsor request appears in Sponsor Lead > Requests to other roles and creates a notification for Sponsor Lead/Chairman/Platform Admin recipients.
- [ ] Sponsor profile changes remain drafts and do not change the public sponsor record until an authorized Sponsor Lead approves them. Approval/decline is audited.

## Finance and media
- [ ] Sponsor contributions are read-only. Attempts to call Sponsor Lead save/receipt RPCs as Sponsor fail; only Treasurer/admin can confirm receipts.
- [ ] Media Team can tag an approved social post or gallery photo for Sponsor A. Sponsor A sees that approved/posted item; Sponsor B does not.
- [ ] Untagged, draft, and unapproved media do not appear in either sponsor portal.
- [ ] Sponsor A can create a signed URL only for its linked agreement documents and tagged gallery photos; Sponsor B cannot create a URL for Sponsor A files.
- [ ] Renewal reminder, pledged/received summary, benefits checklist, public updates and print-to-PDF report render from the linked records only.

## Role regression
- [ ] Verify Chairman, Sponsor Lead, Treasurer, Media Team, Team Manager, Secretary, Coach and Platform Admin workspaces still route as before.
- [ ] Verify Sponsor Lead package, agreement, contribution, benefit, communications, request, report and media calendar workflows remain available.
- [ ] Confirm the new migrations have been applied and the database function/privilege checks pass before merging/deploying.

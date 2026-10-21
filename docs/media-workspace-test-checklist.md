# Media Team, Social Calendar and Fans Gallery — Test Checklist

## Scope and environment
- [ ] Apply \`supabase/migrations/20261022190000_media_social_and_fans_gallery.sql\` to **Union Test first**; do not apply to Production until review and role-based verification pass.
- [ ] Use a confirmed, active \`media_team\` test account, a Platform Admin account, a non-media club role, and an anonymous browser.
- [ ] Use only clearly labelled synthetic test posts and consenting test photos. Do not add real fan or child images without the required permissions.
- [ ] Confirm the existing News workflow remains unchanged; social-post approval uses the new dedicated RPC and must not call the News publication workflow.
- [ ] Verify all changes through the database and audit table, not just the UI.

## Social posts and approval
- [ ] Media Team can create an idea and a drafted post for each channel: Facebook, Instagram, X, TikTok, YouTube and WhatsApp channel.
- [ ] Marking a post posted records an actual publication date; an authorised editor can correct it in the stats form.
- [ ] Required title and channel validation works; planned date, caption/copy and post URL can be saved.
- [ ] A post in \`idea\` cannot be approved directly; move it to \`drafted\` first.
- [ ] Media Team author can approve its own drafted post; database sets \`approved_by\` and \`approved_at\`.
- [ ] Approved post can be marked \`posted\`; a posted post retains its approval metadata.
- [ ] Unapproving returns the post to \`drafted\` and clears approval metadata.
- [ ] Editing an approved or posted post resets it to draft and clears approval metadata.
- [ ] A Media Team user cannot approve another user's social post; the database rejects it even if the RPC is called directly.
- [ ] Media Team members can collaborate on editing posts, manual statistics and gallery photos; edits are audit-logged and edited social posts return to draft.
- [ ] Platform Admin can view and edit another user's post and stats; an override reason is required and the action is recorded in \`private.media_record_audit\` with \`is_admin_override=true\`.
- [ ] News approval and existing news publishing behavior remain unchanged.

## Calendar and manual statistics
- [ ] Month view displays dated posts on the correct day and shows channel/status.
- [ ] List view sorts dated posts chronologically and includes unscheduled posts separately.
- [ ] Month selector and switching between month/list views work on mobile and desktop.
- [ ] Reach, impressions, likes, comments, shares, saves, link clicks, followers gained and post link save and reload correctly.
- [ ] Negative metric values are rejected by the database.
- [ ] Monthly totals, averages per post, per-channel summaries and top five posts by engagement match the saved **posted** records for all-month and selected-month filters; monthly grouping uses the actual posted date.
- [ ] Channel filter changes the summaries and top posts correctly.
- [ ] No passwords, API tokens, recovery codes or social account credentials are collected or stored.

## Fans Gallery and storage
- [ ] Media Team can upload JPEG, PNG and WebP images; upload processing resizes images to no more than 1600 px wide and compresses to WebP.
- [ ] Invalid image types and originals over 15 MB are rejected; Storage bucket enforces an 8 MB uploaded-file limit.
- [ ] Photo date and descriptive alt text are required; caption and match/fixture link are optional.
- [ ] New photo is private/draft until explicitly approved.
- [ ] Consent checkbox text is exactly: “Fans are aware or photo was taken in a public matchday setting”. Approval fails if unchecked.
- [ ] When identifiable children under 18 are flagged, approval fails until child-consent confirmation is checked. Do not approve identifiable children without consent.
- [ ] Media Team can edit, reorder, approve, unapprove and remove gallery photos; editing resets approval and consent confirmations.
- [ ] Platform Admin can override another user's photo and the audit entry records actor, reason, old/new data and override flag.
- [ ] An unapproved photo's image path cannot be read by an anonymous visitor, including through the Storage API.
- [ ] Anonymous and ordinary authenticated non-media accounts can read only approved gallery metadata and approved image objects; they cannot upload, edit, approve or remove photos.
- [ ] Approved gallery public reads expose only the public metadata columns; creator IDs and consent flags are not publicly selectable.
- [ ] Removing/unapproving a photo removes it from the public carousel. Failed file cleanup leaves no publicly readable unapproved image.

## Public carousel
- [ ] 0 approved photos: Fans Gallery section is hidden.
- [ ] 1 approved photo: one card renders without empty/broken slots.
- [ ] 2 approved photos: both render without a broken layout.
- [ ] 3 approved photos: all three are visible on desktop.
- [ ] Many approved photos: previous/next and dots can reach all carousel pages.
- [ ] Desktop shows three cards; mobile shows one card.
- [ ] Touch swipe, previous/next arrows, dots, Left/Right/Home/End keyboard navigation and focus indicators work.
- [ ] Auto-advance is slow, pauses on hover/focus/touch, can be paused manually, and is disabled for \`prefers-reduced-motion\`.
- [ ] Images are lazy-loaded and have the saved alt text; caption/date/optional fixture link render safely.
- [ ] A gallery API/storage error hides the section cleanly without breaking the rest of the homepage.

## Role isolation and regression
- [ ] Media Team-only account routes to \`/app/media.html\`; other roles retain their current routes and workspace access.
- [ ] Generic workspace exposes the Media Team link only to Media Team or Platform Admin.
- [ ] Secretary, Treasurer, Coach, Team Manager, Sponsor Lead, Player and Supporter cannot invoke media mutation RPCs or upload to the gallery bucket.
- [ ] Platform Admin retains access to view/edit/override media records; override reason and audit are present.
- [ ] Existing News, Players, Fixtures, Sponsors, Activities, Finance, Coach and Secretary flows still work.
- [ ] Inspect Supabase Security Advisors and resolve relevant new issues before Production rollout.

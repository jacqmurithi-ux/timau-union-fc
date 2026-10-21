# Homepage hero slider — rollout and test checklist

## Scope
- Homepage header uses the existing red `#c8102e`, crest left, search and menu icons right.
- Public hero reads only current rows from `public.homepage_hero_slides`; images live in the dedicated private `homepage-hero` bucket and Storage RLS permits reads only while a slide is active.
- Admin and Media Team write through guarded RPCs. The database checks roles independently of the UI.
- Audit records contain actor, timestamp, caption and action only. They do not contain image bytes, URLs, or image paths.

## Current rollout status
- [x] Applied all four homepage hero migrations to the **Timau Union FC Production** Supabase project.
- [x] Confirmed the slides table has RLS, the Storage bucket is private, the three-active-slide database trigger exists, and safe-link validation is installed.
- [x] Confirmed there are currently zero active hero slides; no live content was invented or added.
- [x] Deployed `expire-homepage-hero` to Production. Gateway JWT verification is disabled intentionally because the function validates a separate high-entropy token against Supabase Vault through a service-role-only RPC.
- [x] Configured a random `homepage_hero_cron_token` in Vault without exposing its value, configured the public project URL in Vault, and activated `expire-homepage-hero-slides` on a 15-minute schedule.
- [x] Invoked the function through the same Vault-token authorization path used by the schedule; it returned HTTP 200 with `processed: 0` because no expired slides or orphan uploads existed.
- [x] Confirmed the cron authorization RPC denies `anon`, grants execution to `service_role`, and rejects an invalid token.
- [x] GitHub Actions homepage hero validation and Treasurer workspace validation passed before the production-only activation changes.
- [ ] Authenticated browser tests and an actual image upload/replacement/reorder/removal/expiry lifecycle test remain outstanding.
- [ ] Public website deployment could not be independently fetched from this execution environment. Verify the live site after GitHub Pages finishes publishing the current `main` revision.

## Deployment notes
1. Production migrations recorded: `homepage_hero_slides`, `homepage_hero_capacity_guard`, `homepage_hero_link_validation_and_audit`, and `homepage_hero_cron_token`.
2. The expiry Edge Function is deployed in Production as `expire-homepage-hero` with gateway JWT verification disabled; the function checks the dedicated Vault token before any cleanup.
3. The database scheduler reads `project_url` and `homepage_hero_cron_token` from Vault. The service-role key is never stored as a cron secret or placed in Git.
4. The scheduled invocation path was manually verified with HTTP 200. The full real-slide lifecycle still needs authenticated browser testing. Storage is deleted before an expired database row is hard-deleted; failed Storage deletions retain the row for retry.

## Functional checklist
- [ ] Header red is exactly `#c8102e`; crest is left; white/contrast-safe search and hamburger controls are right.
- [ ] Search opens, accepts a query, and returns only public content already exposed by the public site.
- [ ] Hamburger opens existing navigation links on mobile and desktop; Escape closes it.
- [ ] No slides: hero is hidden; header remains.
- [ ] One, two and three slides: only active slides and matching progress segments render.
- [ ] Fourth active slide is rejected with a clear maximum-three message.
- [ ] Segment click selects a slide; active segment fills over about six seconds.
- [ ] Auto-advance, touch swipe, hover pause, keyboard focus and reduced-motion behavior work.
- [ ] Slide link works by tapping the slide and through the accessible caption link.
- [ ] Images have alt text; slides two and three are lazy-loaded.
- [ ] Photo bytes display without tint, filters or blur; sizing uses `object-fit: cover`.
- [ ] Upload accepts JPG/JPEG, PNG and WebP only; images with either dimension above 1920px are resized proportionally without filters.
- [ ] Admin and Media Team can add, edit, reorder and permanently remove slides.
- [ ] Other roles cannot manage slides through UI, table policies, Storage policies or RPCs.
- [ ] Replacing an image removes the prior Storage object.
- [ ] Manual removal deletes the image and hard-deletes the record.
- [x] Expired slides are checked when the workspace loads and by the scheduled Edge Function; scheduled endpoint authorization returned HTTP 200 in Production.
- [ ] If Storage deletion fails, expiry retains the row so cleanup can retry.
- [ ] Verify no orphaned objects remain in `homepage-hero` after a real upload/replacement/removal/expiry lifecycle.
- [ ] Audit rows contain only actor, timestamp, caption and action; no image data/path/URL.
- [ ] Existing header navigation, all other homepage sections, Media Team posts/calendar/stats/gallery and other role workflows still work.

## Notes
- A private Storage bucket is intentional: a public bucket would make non-active or orphaned files publicly addressable. The public hero uses the policy-protected Storage download endpoint.
- Production has not been migrated or changed by this pull request. Do not merge/deploy to Production until the browser checklist, upload/delete/expiry lifecycle tests, and scheduled cleanup are verified.

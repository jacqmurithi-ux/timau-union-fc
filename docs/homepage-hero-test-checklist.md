# Homepage hero slider — rollout and test checklist

## Scope
- Homepage header uses the existing red `#c8102e`, crest left, search and menu icons right.
- Public hero reads only current rows from `public.homepage_hero_slides`; images live in the dedicated private `homepage-hero` bucket and Storage RLS permits reads only while a slide is active.
- Admin and Media Team write through guarded RPCs. The database checks roles independently of the UI.
- Audit records contain actor, timestamp, caption and action only. They do not contain image bytes, URLs, or image paths.

## Deployment prerequisites
1. Apply `supabase/migrations/20261022170000_homepage_hero_slides.sql` to Union Test first and inspect the migration diff before production.
2. Deploy `supabase/functions/expire-homepage-hero` using the Supabase CLI.
3. In Supabase Vault, set secrets named `project_url` (the project HTTPS URL) and `service_role_key` (the service-role key). Never put the service-role key in frontend code or commit it to Git.
4. Re-run the scheduling block at the end of the migration after setting Vault secrets, or schedule the function through the Supabase Dashboard. Confirm `expire-homepage-hero-slides` exists in `cron.job`.
5. Verify the Edge Function is invoked on schedule and check function logs. Expiry removes the Storage object first; the row is hard-deleted only after Storage deletion succeeds.

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
- [ ] Upload accepts JPG/JPEG, PNG and WebP only; wider images resize to at most 1920px without filters.
- [ ] Admin and Media Team can add, edit, reorder and permanently remove slides.
- [ ] Other roles cannot manage slides through UI, table policies, Storage policies or RPCs.
- [ ] Replacing an image removes the prior Storage object.
- [ ] Manual removal deletes the image and hard-deletes the record.
- [ ] Expired slides are checked when the workspace loads and by the scheduled Edge Function.
- [ ] If Storage deletion fails, expiry retains the row so cleanup can retry.
- [ ] No orphaned objects remain in `homepage-hero` after removal, replacement or expiry.
- [ ] Audit rows contain only actor, timestamp, caption and action; no image data/path/URL.
- [ ] Existing header navigation, all other homepage sections, Media Team posts/calendar/stats/gallery and other role workflows still work.

## Notes
- A private Storage bucket is intentional: a public bucket would make non-active or orphaned files publicly addressable. The public hero uses the policy-protected Storage download endpoint.
- This checklist is not a substitute for testing on Union Test and verifying the scheduled cleanup before production rollout.

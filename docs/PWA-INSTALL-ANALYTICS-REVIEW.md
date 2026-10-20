# PWA install analytics — review only

This branch contains a draft migration and standalone files. It is not production-ready.

## Files
- `supabase/migrations/20261021100000_pwa_install_analytics.sql`: private event table, narrow ingestion RPC, admin-only report RPC.
- `js/install-tracking.js`: anonymous tracking, DNT/GPC opt-out, install/prompt/standalone events.
- `admin/installs.html`: admin report UI.
- `manifest.webmanifest` and `service-worker.js`: PWA prerequisites.

## Required integration
1. Add manifest link and tracking script to public page and app shell.
2. Register service worker on HTTPS.
3. Add report link only inside Platform Admin UI; never public navigation.
4. Use Union Test credentials/environment when validating the migration. Do not run against production as part of review.

## Release gates
- Verify duplicate install events count once; different visitor counts once.
- Verify anonymous and non-admin users cannot read events or call install_report.
- Verify report, CSV, acceptance rate, DNT/GPC and no personal fields.
- Verify invalid types and rate limit rejection.
- Run `git grep -i service_role`; it must return no matches.
- No merge to main until the database migration and integration are tested. GitHub Pages may deploy automatically on merge.

# PWA install analytics — release review

The analytics migration is applied to **Union Test only** (`dzpquzfghapjodmrmavw`). Production Supabase and GitHub Pages have not been changed by this migration. Do not merge until the remaining release gates below pass.

## Implementation
- `supabase/migrations/20261021100000_pwa_install_analytics.sql`: private event table, constrained event-ingestion RPC, and active-Platform-Admin report RPC.
- `js/install-tracking.js`: anonymous tracking, DNT/GPC opt-out, install/prompt/standalone events.
- `app/index.html` and `app/access.js`: statistics embedded in the existing protected Platform Admin view; no separate dashboard.
- `manifest.webmanifest` and `service-worker.js`: PWA manifest and public-shell cache. The service worker must never cache private `/app/` pages or auth/API responses.

## Union Test checks completed
- Migration applied successfully to Union Test.
- RLS is enabled on `private.analytics_events`; direct table reads are denied to `anon` and `authenticated`.
- Anonymous execution is allowed for the constrained event-ingestion RPC and denied for the report RPC.
- Transactional tests passed for valid event ingestion, duplicate-install deduplication, invalid-event rejection, the per-visitor rate limit, and denial of report calls for anonymous and non-admin claims.
- The test transaction was rolled back and a follow-up query confirmed zero test rows remain.
- SQL advisor findings reviewed. The private table having RLS without policies is intentional because access is via narrowly granted functions.

## Remaining release gates
1. Union Test has no active Platform Admin account; test the successful report path and metric totals after a test admin is provisioned through the approved setup process.
2. Run browser-based JavaScript, Android/mobile, PWA installability, DNT/GPC, CSV, and share smoke tests.
3. Verify that the club crest/icon has supported dimensions and formats for target browsers.
4. Review the full repository for privileged server credentials; only a publishable browser key belongs in client code.
5. Recheck CI and PR mergeability before merging.

No production migration is authorized by this review. GitHub Pages can deploy automatically after a merge to `main`.

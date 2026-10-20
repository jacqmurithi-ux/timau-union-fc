# Phase 2 rebuild status

- Isolated branch: `draft/phase-2-rebuild-20261020`
- Draft PR: https://github.com/jacqmurithi-ux/timau-union-fc/pull/12
- Union Test only: prior status record reports the role adapter and workspace core migration applied successfully; this record has not independently re-queried the live database.
- Verification: catalog/grant checks passed; Media Team bundle and rollback-only draft-save smoke tests passed; unauthorised sponsor write, publication approval by Media Team, and direct table SELECT were rejected; public anonymous content read returned an empty array.
- Data integrity: zero workspace records and zero audit rows after rollback-only test.
- Production: unchanged; Phase 2 tables and RPCs confirmed absent.
- GitHub Pages/main: unchanged. No Vercel deployment.
- Follow-up: corrected the manual rollback to remove the internal validator helper; rollback remains destructive and must be tested only in a disposable environment.
- Not release-ready: authenticated tests for the corrected role-scoped approval map (Chairman/Secretary all supported record types; Team Manager/Coach players, fixtures/results and activities; Media Team news; Sponsor Lead sponsors; Platform Admin system-wide override), pending/revoked/unconfirmed identities, unknown IDs, malformed/oversized inputs, direct writes, function owners/search_path and actual PostgREST behavior remain outstanding. Re-run security advisors and record outputs.
- Production and public deployment remain separately gated. Do not merge or deploy until all test evidence is recorded and reviewed.

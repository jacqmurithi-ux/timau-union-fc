# Timau Union FC production-readiness audit — 2026-10-23

## Status and safety

- Audit branch: `chore/production-readiness-audit-20261023`, based on `main`.
- Production Supabase project: `owvvimydkjsjlrmnzvdi` (active/healthy).
- Test Supabase project: `dzpquzfghapjodmrmavw` (active/healthy).
- No production writes, schema changes, record deletions, or deployment performed during this audit snapshot.
- This is the initial audit report before fixes. Unknowns remain explicitly unverified; this is not a go-live approval.

## Executive summary

| Severity | Finding | Status |
|---|---|---|
| Critical / release blocker | Homepage hero slides are publicly readable based on expiry only; the table has no publication-status field and the RLS policy does not require approval. The workspace copy says slides publish immediately on save. | Confirmed; not fixed yet |
| High | Financial data does not reconcile at the database snapshot: 1 expense row, 0 ledger rows, 1 financial audit row. Need trace whether this is a legitimate pre-ledger record or test data and fix the canonical accounting flow; do not manually alter totals. | Confirmed inconsistency; not fixed yet |
| High | All 30 production player records are drafts. The records were bulk-created close together, but may be a real roster import; no deletion/publication without provenance review. | Confirmed state; classification pending |
| High | Real-account end-to-end authorization tests for every role and direct API calls have not been performed. Client-side route hiding is not sufficient proof of access control. | Not tested |
| High | Public homepage still reads static JSON for players/matches and contains placeholder sections; this is separate from the approved-content database functions and can drift from the management system. | Confirmed; integration/placeholder audit pending |
| High | Public SECURITY DEFINER RPCs `get_published_club_content()` and `treasurer_public_published_reports()` are executable by anon. This may be intentional, but their returned fields/content and published-only filtering must be verified. | Needs function-level review |
| Medium | Supabase advisor reports missing indexes for several foreign keys, auth/RLS expressions re-evaluated per row, and duplicate permissive SELECT policies on gallery/social posts. | Confirmed advisor findings; not fixed |
| Medium | Root README still describes the management system as a placeholder and says no Supabase backend is included, inconsistent with current pages and connected production database. | Confirmed; docs stale |
| Medium | Sponsor packages and templates include starter/sample-style records; there is also a draft sponsor proposal/prospect. These may be intentional starter material, not safe to delete without classifying provenance. | Confirmed records; classification pending |
| Medium | User-visible confirmation, duplicate-submit prevention, empty/error states, responsive behavior, session expiry/sign-out clearing and offline/retry behavior require page-by-page runtime verification. | Not fully tested |
| Medium | Current database schema contains a private monthly attendance view, but the existence of a view/function alone does not prove the dashboard/report flow is wired end to end. | Needs integration tests |

## Database inventory (production snapshot)

Catalog query scope: `public` and `private` schemas. Counts at audit time: **47 tables, 1 view, 119 functions, 47 RLS policies; 111 functions are SECURITY DEFINER**. The private schema is not usable by anon; it is usable by authenticated, and direct table policies on private tables deny direct access. Privileged functions therefore require careful per-function review.

### Tables

**public (11):** `fan_gallery`, `first_aid_items`, `homepage_hero_slides`, `kit_alerts`, `kit_items`, `kit_managers`, `kit_movements`, `match_attendance`, `social_followers`, `social_post_stats`, `social_posts`.

**private (36):** `account_access`, `audit_events`, `club_financial_audit`, `club_financial_expenses`, `club_financial_ledger`, `club_record_audit`, `club_records`, `coach_records`, `homepage_hero_audit`, `media_record_audit`, `platform_admins`, `role_assignments`, `secretary_records`, `sponsor_agreements`, `sponsor_benefit_delivery`, `sponsor_communications`, `sponsor_contributions`, `sponsor_evaluation_settings`, `sponsor_media_shares`, `sponsor_packages`, `sponsor_portal_notifications`, `sponsor_private_details`, `sponsor_profile_edits`, `sponsor_proposal_templates`, `sponsor_proposal_versions`, `sponsor_proposals`, `sponsor_prospect_evaluations`, `sponsor_prospects`, `sponsor_role_requests`, `sponsor_user_links`, `sponsor_workspace_audit`, `tm_record_audit`, `tm_records`, `treasurer_opening_balance`, `treasurer_records`, `user_profiles`.

**View (private):** `home_attendance_monthly`.

### Database functions

The catalog contains 119 functions. Names/signatures observed:

**private:** `can_access_sponsor_agreement(_agreement_id uuid)`, `can_access_sponsor_agreement_object(_name text, _operation text)`, `can_access_sponsor_workspace(_area text)`, `can_manage_club_record(_roles text[], _is_platform_admin boolean, _created_by uuid)`, `current_club_roles()`, `current_sponsor_record_id()`, `enforce_homepage_hero_active_limit()`, `guard_attendance_fixture_update()`, `is_active_platform_admin(_user_id uuid)`, `kit_can_manage()`, `kit_can_read()`, `kit_guard_first_aid_update()`, `kit_guard_insert()`, `kit_guard_item_update()`, `kit_guard_movement()`, `kit_is_coach()`, `kit_is_writer()`, `kit_notify_attention()`, `on_auth_user_created()`, `role_can_approve_record(_roles text[], _type text)`, `role_can_manage_record(_roles text[], _type text)`, `secretary_actor_can_manage()`, `secretary_edit_distance(a text, b text)`, `sponsor_can_read_agreement_path(_name text)`, `sponsor_can_read_tagged_media_path(_name text)`, `sponsor_eval_can_manage()`, `sponsor_proposal_immutable_guard()`, `sponsor_proposal_version_guard()`, `sponsor_workspace_guard()`, `touch_updated_at()`, `user_has_active_club_role(_user_id uuid, _role text)`, `valid_club_record_data(_type text, _data jsonb)`, `valid_coach_record_data(_section text, _data jsonb)`, `valid_tm_record_data(_s text, _d jsonb)`, `validate_home_attendance_fixture()`.

**public (observed RPCs):** `admin_assign_club_role`, `admin_get_audit_events`, `admin_list_access_requests`, `admin_set_account_status`, `club_get_financial_summary`, `club_get_workspace_bundle`, `club_save_record`, `club_set_publication_status`, `coach_get_dashboard`, `coach_save_record`, `coach_set_publication_status`, `get_my_access_status`, `get_published_club_content`, `home_attendance_get_report`, `homepage_hero_can_manage`, `homepage_hero_cron_authorized`, `homepage_hero_expire`, `homepage_hero_expire_from_workspace`, `homepage_hero_expired_paths`, `homepage_hero_is_current_user_platform_admin`, `homepage_hero_remove`, `homepage_hero_save`, `kit_get_fixtures`, `kit_get_people`, `kit_record_movement`, `media_can_manage`, `media_get_share_options`, `media_get_workspace`, `media_is_current_user_platform_admin`, `media_remove_fan_photo`, `media_reorder_fan_photos`, `media_save_fan_photo`, `media_save_social_post`, `media_save_social_stats`, `media_set_fan_photo_status`, `media_set_social_status`, `media_set_sponsor_shares`, `secretary_find_player_duplicates`, `secretary_get_workspace`, `secretary_log_duplicate_decision`, `secretary_merge_player_records`, `secretary_save_record`, `secretary_set_status`, `social_monthly_summary`, `social_sponsor_posts`, `social_stats_touch_updated_at`, `sponsor_eval_approve_risky`, `sponsor_eval_get_workspace`, `sponsor_eval_save`, `sponsor_eval_save_settings`, `sponsor_home_attendance_summary`, `sponsor_lead_confirm_receipt`, `sponsor_lead_create_agreement_upload_url`, `sponsor_lead_get_link_options`, `sponsor_lead_get_links`, `sponsor_lead_get_portal_notifications`, `sponsor_lead_get_workspace`, `sponsor_lead_review_profile_edit`, `sponsor_lead_save_record`, `sponsor_lead_set_user_link`, `sponsor_packages_seed_starters`, `sponsor_portal_get`, `sponsor_portal_save_details`, `sponsor_portal_submit_request`, `sponsor_proposal_save`, `sponsor_proposal_set_status`, `sponsor_template_save`, `sponsor_template_update`, `tm_get_audit`, `tm_get_expenses`, `tm_review_expense`, `tm_save_record`, `tm_set_publication_status`, `tm_submit_expense`, `treasurer_confirm_opening_balance`, `treasurer_create_adjustment`, `treasurer_get_dashboard`, `treasurer_get_period_summary`, `treasurer_public_published_reports`, `treasurer_receipt_access`, `treasurer_review_record`, `treasurer_review_tm_transport`, `treasurer_save_record`, `treasurer_submit_requisition`.

### RLS policy inventory

**private (11 deny-direct-access policies):** `club_financial_audit_no_direct_access`, `club_financial_expenses_no_direct_access`, `club_financial_ledger_no_direct_access`, `club_record_audit_no_direct_access`, `club_records_no_direct_access`, `coach_records_no_direct_access`, `secretary_records_no_direct_access`, `tm_record_audit_no_direct_access`, `tm_records_no_direct_access`, `treasurer_opening_balance_no_direct_access`, `treasurer_records_no_direct_access`.

**public (36 policies):** `fan_gallery_media_read`, `fan_gallery_public_approved_read`, `first_aid_items_insert`, `first_aid_items_no_delete`, `first_aid_items_read`, `first_aid_items_update`, `homepage_hero_public_active_read`, `kit_alerts_insert`, `kit_alerts_no_delete`, `kit_alerts_read`, `kit_alerts_update`, `kit_items_insert`, `kit_items_no_delete`, `kit_items_read`, `kit_items_update`, `kit_managers_delete`, `kit_managers_insert`, `kit_managers_no_update`, `kit_managers_read`, `kit_movements_insert`, `kit_movements_no_delete`, `kit_movements_no_update`, `kit_movements_read`, `attendance authorized editors`, `attendance authorized writers`, `attendance internal readers`, `social_followers_insert`, `social_followers_read`, `social_followers_update`, `social_post_stats_insert`, `social_post_stats_read`, `social_post_stats_update`, `social_posts_media_read`, `social_posts_stats_internal_insert`, `social_posts_stats_internal_read`, `social_posts_stats_internal_update`.

Note: policy existence is not a security test. The actual `USING` / `WITH CHECK` logic and direct API behavior must be tested for each role.

## Front-end files inspected in this snapshot

Core files reviewed for initial signals: `index.html`, `script.js`, `styles.css`, `app/index.html`, `app/private-nav.js`, `app/role-navigation.js`, `app/workspace.html`, `app/treasurer.html`, `app/treasurer.js`, `app/kit.html`, `app/kit.js`, `app/sponsor-lead.html`, `app/sponsor-lead.js`, `app/sponsor.html`, `app/sponsor.js`, `app/media.html`, `app/secretary.html`, `app/home-attendance.html`, `app/social-stats.html`.

The repository-wide HTML/JS/CSS/asset path inventory is still open; no claim is made that every file has been inspected yet. Static front-page logic fetches `data/players-2025-26.json` and `data/matches.json`, while homepage CSS contains placeholder-content rules. The client-side Supabase key observed in the inspected modules is a publishable key; no service-role/secret key was found in these inspected snippets. Full repository-wide secret scanning is not yet complete.

## Flow verification matrix (audit baseline)

| Flow | Result | Evidence / blocker |
|---|---|---|
| Admin onboarding, role assignment, sign-in, password reset | NOT TESTED | Requires real-account browser testing including email/reset links. |
| Players import/draft/approve/publication | PARTIAL / NOT END-TO-END | 30 production records are draft; public page reads static JSON; test actual workflow and published data source. |
| Fixtures/results/approval/publication/news | NOT TESTED | Public fixtures read static JSON; trace full save/approve/public pipeline. |
| Home attendance/monthly summary | PARTIAL | Table and `home_attendance_monthly` view exist; no end-to-end write/read test performed. |
| Kit item/custodian/issue/return/first aid/sponsor-funded kit | PARTIAL | Schema, RLS, kit RPCs and one item/three movements exist; real Coach/Kit Manager tests pending. |
| Finance, opening balance, income/expenses, approvals, transport, receipts, ledger/audit/reports | BLOCKED | Ledger is empty while expense/audit rows exist; must trace canonical accounting pipeline before further production entries. |
| Sponsor records/funds/kit/own-data portal | PARTIAL | Tables/RPCs exist; one sponsor record and draft starter material exist; cross-sponsor isolation not tested. |
| Media/social stats/monthly summary | PARTIAL | Tables/RPCs exist; no social post/stats rows; RLS and monthly calculations not runtime-tested. |
| Monthly sponsor report draft/approve/publish/PDF/CSV | NOT TESTED | Public report RPC exists; report UI/export flow and published-month filtering need verification. |
| Public website shows approved/published only | FAIL / BLOCKED | Hero slide RLS has no approval-status check; static player/match JSON is not linked to database publication state. |

## Role verification baseline

Admin, Chairman, Vice Chairman, Secretary, Treasurer, Team Manager, Coach, Media Team, Sponsor Lead, Sponsor and Kit Manager direct-URL and direct-API tests have **not** been completed. Navigation map checks from the previous PR are static checks only. Sponsor isolation, Coach vs Kit Manager writes, Treasurer-only financial writes, and public/anon draft isolation remain release gates.

## Required next actions (in order)

1. Inspect exact hero slide policy and RPC behavior; propose a narrowly scoped fix so public access requires explicit approval/publication.
2. Trace finance save/review/ledger/audit functions and explain the expense-vs-ledger discrepancy before touching amounts or records.
3. Classify production records by provenance; report ambiguous player, sponsor, package, proposal, kit and homepage records before any deletion.
4. Complete repository file/link/script inventory and inspect every role/page entry point.
5. Add automated/static tests and a documented manual browser matrix; run real-account tests where credentials and test accounts are available.
6. Review function ACL/search_path/input validation and Supabase advisor findings; do not broadly revoke privileges or alter role permissions without evidence.
7. Implement verified fixes in small commits on this branch, with migrations proposed and reviewed before production application.
8. Update deploy/backup/restore/rollback README and first-week checklist; keep GitHub Pages from `main` as the only production deployment path.

**Go-live status: NOT READY.** No workflow is marked passed unless a test has actually run.

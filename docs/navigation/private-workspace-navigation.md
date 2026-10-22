# Private workspace navigation

## Scope

The private management pages use app/private-nav.js as the single shared navigation component. It removes the header's page links, keeps the crest/name and Sign out button, then builds the in-content tab row from the signed-in session's existing role bundle. Public pages are not changed.

The shared row reuses existing role checks and links. Public website and Member access links are retained as tabs so removing the old header links does not discard destinations. It does not grant database access or replace RPC/RLS authorization. The Club workspace's Players, Fixtures & results, News, Sponsors and Activities tabs remain in-place section switches on workspace.html; from other pages those tabs navigate back to the matching workspace section. The shared component moves the existing page-specific tab controls into the same visual row after that workspace is authorized and visible. It reuses the existing buttons and their event handlers rather than copying them, so Treasurer reports, Media Team social statistics, Secretary Documents, Coach sections and Sponsor Lead/Sponsor portal sections continue switching in place.

## Shared page-tab visibility

- **Public website / Member access:** available as navigation destinations to every signed-in private workspace user.
- **Club workspace:** roles that can use the shared records workspace; dedicated-only Coach, Media Team, Sponsor Lead, Treasurer and Sponsor sessions are not shown a workspace tab when the existing page redirects them to their dedicated workspace/portal.
- **Coach workspace:** Coach, plus existing Chairman / Platform Admin oversight.
- **Secretary workspace:** Secretary, plus existing Chairman / Platform Admin oversight.
- **Treasurer workspace:** Treasurer, Secretary, Chairman, Vice Chairman, Sponsor, Sponsor Lead, Team Manager, Coach, Player, plus existing Platform Admin access. The page's existing RPC remains the final authority.
- **Media Team:** Media Team, plus existing Chairman / Platform Admin oversight.
- **Sponsor Lead:** Sponsor Lead, plus existing Chairman / Platform Admin oversight.
- **Sponsor portal:** Sponsor role only.
- **Sponsor account links:** Sponsor Lead and existing Chairman / Platform Admin oversight.
- **Kit & equipment:** Team Manager, Coach, Assistant Coach, Secretary, plus existing Chairman / Platform Admin oversight.
- **Home attendance:** Team Manager, Secretary, Chairman, Vice Chairman, Treasurer, Coach, Media Team, Sponsor Lead, plus existing Platform Admin access.
- **Players:** Team Manager and Secretary, plus Chairman / Platform Admin.
- **Fixtures & results:** Team Manager and Secretary, plus Chairman / Platform Admin.
- **News:** Media Team and Secretary, plus Chairman / Platform Admin.
- **Sponsors:** Sponsor Lead and Secretary, plus Chairman / Platform Admin.
- **Activities:** Team Manager and Secretary, plus Chairman / Platform Admin.

These are navigation visibility rules only. If a legacy page-level rule differs, do not loosen it to make a tab work; reconcile the navigation to the existing page/RPC access contract.

## Manual regression checklist

At 360px viewport width, for each role below:
1. Sign in and open the role's first page and each linked management page.
2. Confirm the header is a single row: crest and TIMAU UNION FC on the left; Sign out on the right. Confirm no old page links or subtitle remain in the header and no overlap/wrapping occurs.
3. Confirm the shared tab row wraps cleanly, uses black rounded buttons and highlights the current page/section in red.
4. Confirm same-page tabs change the section without a reload; cross-page tabs open the expected page.
5. Confirm no tab appears for a role that the destination page's existing access checks reject.
6. Sign out and confirm the public site header/navigation is unchanged.

Role-specific coverage:
- **Secretary:** Players, Fixtures & results, News, Sponsors, Activities, Secretary workspace, Treasurer requisitions view, Kit & equipment, Home attendance; Documents remains a Secretary in-page tab.
- **Treasurer:** Treasurer workspace, Club workspace only when the existing combined-role rules permit it, Home attendance; verify finance tabs still switch in place.
- **Team Manager:** Players, Fixtures & results, Activities, Club workspace, Kit & equipment, Home attendance, and Treasurer requisitions view where the existing page permits it.
- **Coach:** Coach workspace, Kit & equipment, Home attendance, and Treasurer view where the existing page permits it. Confirm Coach-only accounts are not offered the Club workspace redirect.
- **Media Team:** Media Team workspace and Home attendance; Social stats remains an in-page tab.
- **Sponsor Lead:** Sponsor Lead workspace, Sponsor account links, Home attendance and Treasurer view where the existing page permits it; sponsor portal requests remain an in-page section.
- **Sponsor:** Sponsor portal and the existing read-only Treasurer view; no Club workspace redirect tab.
- **Chairman / Platform Admin:** verify the existing oversight tabs appear, and the Sponsor portal remains sponsor-account-specific.

## Files

- app/private-nav.js — shared role-aware navigation, compact header styles, active-state, and moving existing page section controls into the shared row without copying their handlers.
- app/workspace.html, app/coach.html, app/treasurer.html, app/secretary.html, app/sponsor-lead.html, app/kit.html, app/home-attendance.html, app/media.html, app/sponsor-links.html — remove header links and subtitle.
- app/sponsor.html — remove header links and subtitle, and load the shared component.

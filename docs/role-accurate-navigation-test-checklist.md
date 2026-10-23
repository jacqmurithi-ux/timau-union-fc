# Role-accurate private navigation test checklist

## Scope and safety

- [ ] Use a separate test account for each role, or change the test account's existing role assignments in the approved test environment.
- [ ] Do not alter RLS, SQL functions, role assignments, or grants for this UI test.
- [ ] Confirm the page loads the shared `app/role-navigation.js` map and `app/private-nav.js` component.
- [ ] Test mobile width (360–390 px) and desktop width.
- [ ] Confirm the header contains only the club logo/name and Sign out.
- [ ] Confirm the current page link is the only red navigation item; section buttons remain black.
- [ ] Confirm multiple-role accounts see the union of authorized page/section links with no duplicates.

## Central role-to-pages map

The map is maintained in `app/role-navigation.js`. The route column lists the expected landing workspace; other visible links must be the union of the page and section access entries in that file.

| Role | Expected home | Expected page/section navigation |
|---|---|---|
| Platform Admin / Admin | Club workspace | All configured routes and sections; existing database permission checks still decide actions |
| Chairman | Club workspace | Club workspace, Coach, Secretary, Treasurer, Media, Sponsor Lead, Kit, attendance, and reports where configured |
| Vice Chairman | Home attendance | Home attendance only unless another assigned role grants additional pages |
| Secretary | Secretary workspace | Secretary records, meetings/minutes, correspondence, registration, membership, documents, notices, elections, reports, and configured shared records |
| Treasurer | Treasurer workspace | Money in, money out, transport approvals, opening balance, budget, requisitions, sponsor funds, contributions, cash book, financial reports, audit log |
| Team Manager | Club workspace | Players, fixtures/results, activities, squad administration, match day, transport/logistics, team sheets, discipline/welfare, communications, training coordination and reporting |
| Coach | Coach workspace | Fixtures/results, activities, squad, training plans/attendance, match selection, tactics, performance, match analysis, player development, fitness and discipline summary; no finance tabs |
| Assistant Coach | Kit & equipment | Kit page only unless another assigned role grants more |
| Media Team | Media workspace | Social posts, calendar, stats, gallery and homepage hero; no Treasurer tabs |
| Sponsor Lead | Sponsor Lead workspace | Sponsor records, pipeline/evaluation, templates, proposals, packages, agreements, benefits, communications, requests and sponsor reports; no Treasurer tabs |
| Sponsor | Sponsor portal | Own partnership, agreement, contributions, benefits, updates, media, requests, report and details; no internal management pages |
| Kit Manager | Kit & equipment | Kit & equipment page; no Treasurer tabs |
| Player Welfare | Club workspace | Welfare and configured Club workspace sections only |
| Player | Member access | No internal management navigation unless another assigned role grants access |
| Supporter | Member access | Public/member access only; no private management navigation |

> The table is the expected presentation map. If code/database review shows a role cannot open or use an entry, remove it from `SECTION_ACCESS` / `PAGE_ACCESS`; do not grant access to make a navigation test pass.

## Per-role execution

For each role above:

1. Sign in as that role and record the displayed role label. It must use readable words (for example, “Sponsor Lead”), not underscore-separated identifiers.
2. Confirm only the mapped page buttons and section buttons are visible. In particular, Sponsor Lead must not see Opening balance, Income records, Expense records, Transport approvals, Budget, Cash book & receipts, Audit log or other Treasurer-only sections.
3. Open every visible page link and section button. Confirm it opens the expected page/section, not an error, blank panel or unrelated workspace.
4. Verify exactly one page link is red: the current page. Section buttons stay black even when their section is selected.
5. Paste a direct URL for one forbidden page (for example, Sponsor Lead → `treasurer.html`; Sponsor → `sponsor-lead.html`; Coach → `treasurer.html`; Player → `workspace.html`). Confirm redirect to that role's home and the exact message: “You don't have access to that page.”
6. Test the same account at mobile and desktop widths; ensure the header remains logo, club name and Sign out only.
7. For multi-role accounts, confirm the union of permitted buttons appears once each and every link works.

## Role-specific forbidden-route examples

| Signed-in role | Forbidden direct URL | Expected result |
|---|---|---|
| Admin / Chairman | Use a page not in the configured route map | Redirect to Club workspace with the access message |
| Vice Chairman | `treasurer.html` | Redirect to Home attendance |
| Secretary | `sponsor-lead.html` | Redirect to Secretary workspace |
| Treasurer | `sponsor-lead.html` | Redirect to Treasurer workspace |
| Team Manager | `treasurer.html` | Redirect to Club workspace |
| Coach | `treasurer.html` | Redirect to Coach workspace |
| Assistant Coach | `treasurer.html` | Redirect to Kit & equipment |
| Media Team | `treasurer.html` | Redirect to Media workspace |
| Sponsor Lead | `treasurer.html` | Redirect to Sponsor Lead workspace |
| Sponsor | `sponsor-lead.html` | Redirect to Sponsor portal |
| Kit Manager | `treasurer.html` | Redirect to Kit & equipment |
| Player Welfare | `treasurer.html` | Redirect to Club workspace |
| Player | `workspace.html` | Redirect to Member access |
| Supporter | `workspace.html` | Redirect to Member access |

## Regression checks

- [ ] The Treasurer page has no Sponsor Lead link exposure or Sponsor Lead title.
- [ ] Existing page-level action checks still work; navigation filtering is not treated as a security boundary.
- [ ] No SQL migration, RLS policy, database function, role assignment or grant changed.
- [ ] Existing Kit data, page and permissions are unchanged.
- [ ] Verify each route/section with an actual signed-in test account before merge. Static checks alone do not prove runtime authorization.

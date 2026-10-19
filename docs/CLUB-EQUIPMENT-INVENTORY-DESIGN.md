Timau Union FC — Club Equipment & Kit Inventory Design

Status: Design proposal — review decisions recorded; implementation on hold
Scope: Design only
Related documents: ""features-flow.md"" (../features-flow.md), ""AUTHENTICATION-DESIGN.md"" (./AUTHENTICATION-DESIGN.md)

1. Purpose

Design a secure, mobile-first inventory workflow for recording, issuing, returning, inspecting, maintaining and reporting on Timau Union FC property.

The inventory covers all club property, including:

- Playing kits and training wear
- Footballs, cones, bibs, nets, goalkeeping gear and training equipment
- Medical, first-aid and match-day supplies
- Office equipment, furniture and storage items
- Other property purchased, donated, transferred or carried forward into the register

The system must support both quantity tracking and individual-item tracking. The Team Manager is the day-to-day inventory maintainer, within explicitly granted permissions. A designated backup maintainer may perform assigned duties when the Team Manager is unavailable.

2. Design principles

1. Maintain one dependable club inventory register with a traceable history.
2. Record quantity, condition, location, custody and lifecycle status as separate facts.
3. Record the source of each item or stock batch: purchased, donated, transferred, opening inventory or other.
4. Record receipts, issues, returns, movements, adjustments and disposals as history rather than silently overwriting prior records.
5. Use least-privilege access. Inventory responsibilities do not automatically grant financial approval or access to unrelated private records.
6. Keep private inventory, donor and custody information out of the public website.
7. Make common tasks usable on mobile phones and with limited data.
8. Enforce authorization in trusted backend/database controls. Hiding a menu or button is not a security boundary.
9. Require independent review of significant stock adjustments and disposals.
10. Conduct stocktakes quarterly and additionally at season changes and handovers.

3. Inventory categories

Initial suggested categories:

- Playing kits: jerseys, shorts, socks, goalkeeper kits, training wear and bibs.
- Football and training equipment: balls, cones, ladders, hurdles, poles, nets, pumps and other training aids.
- Goalkeeping and protection: gloves, pads and protective equipment.
- Medical and safety supplies: first-aid kits, reusable medical equipment and consumables.
- Match-day equipment: flags, corner poles, water containers and other approved club property.
- Office equipment: phones, computers, printers, routers and accessories.
- Furniture and fixtures: desks, chairs, cabinets, shelves and storage units.
- Other property: any item approved for inclusion in the club register.

Categories should be configurable by authorized officials without changing the permission model.

4. Two tracking methods

4.1 Quantity-tracked stock

Use this for items managed as a countable stock quantity, especially consumables or interchangeable items.

Suggested fields:

- Inventory record ID
- Item name, category and description
- Unit of measure, such as each, pair, pack or box
- Size, variant or other distinguishing attribute where relevant
- Quantity received, available, reserved, issued, damaged or otherwise unavailable
- Storage location
- Minimum-stock threshold, if applicable
- Acquisition/donation source and receipt date
- Reference to supporting receipt or record, if available
- Movement history and recording official

Quantities must reconcile through recorded movements. A stock adjustment must include a reason and must not erase earlier entries.

4.2 Individually tracked assets

Use this for identifiable equipment or property that needs its own custody, condition, repair or retirement history.

Suggested fields:

- Unique internal asset ID
- Item name and category
- Brand, model or serial number, when applicable
- Date received and source
- Condition at receipt
- Current status, location and custodian
- Acquisition value, only for authorized users where recorded
- Issue and return history
- Inspection, repair and maintenance history
- Loss, damage, transfer and retirement records

The internal asset ID is distinct from a manufacturer serial number and from any printed squad number.

5. Jersey and kit tracking

The kit register should support:

- Kit type or season, such as home, away, goalkeeper or training
- Jersey size, using the club's agreed size list
- Printed squad number
- Unique item ID where each jersey is individually tracked
- Condition and current location
- Availability, issue and return status
- Player or authorized custodian currently holding the item
- Issue date, expected return date and actual return date
- Damage, replacement, loss and repair history

A printed squad number must not be used as the database identity of a jersey. The same number may legitimately appear on a different kit type or in a different season. The register should flag potential duplicate active assignments for review, while allowing authorized officials to document approved exceptions.

Players do not need login accounts. Authorized officials record kit issues and returns. A future signed acknowledgement or printed issue slip may be considered separately.

6. Donations and acquisitions

Each receipt or intake should identify its source:

- Purchased by the club
- Donated
- Transferred from another organization or person
- Opening inventory
- Other, with explanation

For donations, capture where available:

- Item or stock description and quantity
- Condition at receipt
- Donor name or organization
- Date received
- Any restrictions or intended use
- Acknowledgement status or reference
- Supporting note or receipt, if available
- Official recording the receipt
- Review or verification status, where required

Do not invent a donor name, date or value if unknown. Mark the information as unknown or not provided. Donor contact details and internal donation notes are private and visible only to authorized roles.

Recording a donated asset does not itself create a cash transaction. The Team Manager's inventory role does not authorize spending, payment approval or alteration of financial records.

7. Item lifecycle and movements

Suggested statuses, subject to category-specific rules:

- Available
- Reserved
- Issued
- Returned and awaiting inspection
- Damaged
- Under repair
- Lost or missing
- Retired or disposed

7.1 Receive stock or an asset

1. Select or create the item record.
2. Record quantity or individual asset details.
3. Record source, receipt date, condition and location.
4. Attach a supporting reference where available.
5. Submit for any required review.
6. Add the receipt to the movement history.

7.2 Issue equipment or kit

1. Select available stock or an individual asset.
2. Record the recipient/custodian, purpose and issue date.
3. Record the expected return date if the item is loaned.
4. Check that stock or asset availability permits the issue.
5. Save the movement and update current availability.
6. Keep a permanent issue history.

7.3 Return equipment

1. Find the active issue record.
2. Record return date, quantity and observed condition.
3. Route damaged items to inspection or repair.
4. Return serviceable items to available stock or their storage location.
5. Preserve the issue and return history.

7.4 Record damage, loss, repair or disposal

1. Select the affected item or stock record.
2. Record what happened, when it was noticed and who reported it.
3. Record the action taken and supporting details.
4. Require independent review for significant stock adjustments, losses requiring write-off, write-offs and disposals, according to the approved permission matrix.
5. Prevent the person who recorded or proposed the action from approving that same action.
6. Keep actions requiring review in a pending state until a separate authorized reviewer approves or rejects them.
7. Preserve the audit trail and prior state.

The system should prevent negative stock, impossible status transitions and duplicate active custody of the same individually tracked asset.

The threshold for a significant adjustment or disposal remains to be defined in the final permission matrix. Until approved, the design must not assume a monetary or quantity threshold.

8. Storage, custody and stocktake

Inventory records should support storage locations such as the club store, training ground, office or another approved location.

For individually tracked items, maintain current custody and handover history. For quantity stock, maintain quantities by location when the club needs to distinguish stock held in multiple places.

8.1 Stocktake frequency

Stocktakes must take place:

- Quarterly: a scheduled physical count or asset verification.
- At season changes: checks when equipment is prepared for or returned from a new season.
- At handovers: checks when inventory responsibility, custody or relevant storage arrangements change.

Additional checks may be arranged when loss, damage, discrepancies or other operational concerns justify them.

8.2 Stocktake workflow

An authorized official should be able to:

1. Select a location or category.
2. Count physical stock or confirm individual assets.
3. Compare observed counts with recorded quantities and statuses.
4. Record missing, extra, damaged or misplaced items.
5. Submit discrepancies for review.
6. Apply approved corrections as traceable adjustments.

A stocktake must not silently overwrite the system quantity. The system should preserve the count, discrepancy reason, reviewer and resulting adjustment.

A stocktake discrepancy does not itself authorize a write-off or disposal. Any adjustment requiring approval must follow the independent-review workflow.

8.3 Backup inventory maintainer

The Chairman designates an authorized backup inventory maintainer for periods when the Team Manager is unavailable.

- The designation must be explicit and recorded.
- The backup receives only the inventory capabilities assigned to that role.
- Backup access does not automatically grant financial authority, role-management authority or access to unrelated confidential records.
- The backup's actions must be attributed to their own account in the audit history.
- Any temporary access arrangements must be reviewed and withdrawn when no longer needed.

The backup maintainer may perform routine tasks within their permissions but cannot approve their own significant adjustments or disposals.

9. Proposed screens

1. Inventory dashboard: counts by category and status, low-stock warnings, overdue returns and pending reviews.
2. Inventory register: search and filters for category, size, squad number, condition, location, source and tracking method.
3. Item detail: current details, history, custody, documents and permitted actions.
4. Receive items: purchased, donated, transferred and opening inventory intake.
5. Issue and return: simple phone-friendly workflows for kits and equipment.
6. Stocktake and discrepancies: physical count, variance explanation and review.
7. Maintenance and retirement: repairs, losses, write-offs and disposals.
8. Reports: permission-filtered summaries and history.
9. Review queue: pending significant adjustments, disposals and other actions requiring independent approval.
10. Inventory access and handover: authorized backup designation and relevant handover records, accessible only to officials with the appropriate permissions.

Do not expose the inventory register or private item details on public pages.

10. Proposed role and permission boundaries

The exact capability matrix must be approved before implementation. Suggested starting point:

- Team Manager: day-to-day register maintenance, receipts, issues, returns, location updates and stocktake preparation, within assigned scope.
- Designated backup inventory maintainer: routine inventory duties when designated, within explicitly granted scope.
- Chairman: designates the backup maintainer, provides oversight and performs explicitly assigned approvals. This does not mean every action must be Chairman-only.
- Treasurer: access to acquisition costs and finance-related references only where authorized; financial approval remains governed by separate finance permissions.
- Secretary: selected view or recordkeeping tasks only when explicitly granted.
- Coach: view relevant equipment availability and submit equipment requests; no automatic authority to change inventory records.
- Other officials: only the specific capabilities explicitly granted.
- Players: no login accounts; their kit/equipment custody may be recorded by authorized officials.
- Public/supporters: no access to private inventory, donor details, custody records or internal reports.

Permissions should distinguish at least:

- View records
- Create receipts
- Issue items
- Record returns
- Edit descriptive fields
- Change custody or location
- Adjust quantities
- Propose significant adjustments
- Review or approve significant adjustments
- Propose disposals
- Review or approve disposals
- View acquisition values
- View donor contacts
- Export reports
- View audit history
- Designate or maintain backup access, where authorized

Do not bundle sensitive permissions together without a deliberate decision.

Independent approval rule

The person who records or proposes a significant adjustment or disposal cannot approve that same action. A second authorized official must independently review it. The system must record the proposer, reviewer, decision, timestamp and reason where applicable.

11. Reports and exports

Suggested reports:

- Inventory summary by category, tracking method and status
- Kit availability by size, kit type and squad number
- Currently issued items and expected returns
- Overdue returns
- Damaged items and repair queue
- Donation register and intake history
- Acquisition register
- Stocktake results and unresolved discrepancies
- Individual asset history
- Low-stock list and replenishment needs
- Inventory handover summary
- Pending and completed adjustment/disposal reviews

Export permissions

All authorized officials may export inventory reports, subject to their existing access permissions for the underlying data.

This means:

- Export access does not grant permission to view records, fields or reports otherwise restricted to that official.
- Acquisition values, donor contact details, sensitive custody information and confidential audit details must remain excluded unless the exporting official is separately authorized to view them.
- Exports must apply the same access rules as the corresponding on-screen report.
- Export activity should be logged, including the user, time, report type and applicable filters where practical.
- Exported files must be handled as private club records and must not be published to the public website without a separate authorization and privacy review.

12. Security, privacy and audit requirements

- Supabase Auth identifies signed-in users; database Row Level Security (RLS) and trusted backend authorization remain the security boundary.
- Apply least privilege and deny access by default.
- Protect every read and write path, including direct API requests, report endpoints, exports and file access.
- Do not put service-role keys or other privileged secrets in browser code.
- Validate quantity changes, status transitions, club ownership and permissions on the trusted side.
- Keep an audit history for receipts, issues, returns, edits to material fields, transfers, stock adjustments, approvals, repairs, losses, disposals, backup designations and exports where appropriate.
- Record who performed an action and when; include a reason for sensitive corrections.
- Prevent self-approval of significant adjustments and disposals.
- Keep donor contact information, acquisition values, custody details and internal notes private.
- Limit uploaded evidence to authorized users and validate its access rules.
- Fail closed if permissions cannot be confirmed.
- Do not allow inventory permissions to grant access to player welfare, private finance, authentication administration or unrelated records.

This document proposes requirements only; it does not define or change SQL, schema, policies, grants or backend functions.

13. Mobile-first usability

The interface should work on small screens, use plain language, minimize repeated typing and avoid unnecessary large downloads. Common tasks—receive, issue, return and record damage—should be short, with clear confirmation before saving.

Search and filters should work well with the club's expected item names, sizes and squad numbers.

Where connectivity is unreliable, the system must not claim that a change was saved until the trusted backend confirms it. Any future offline workflow would need a separate design for conflicts, duplicate submissions and authorization.

14. Acceptance criteria for a future implementation

The implementation is not ready for authorization until it can demonstrate that:

- Both quantity tracking and individual asset tracking are supported.
- Jersey size and printed squad number are searchable and distinct from the internal item ID.
- Donated items retain donor/date/source details where provided, with private information access-controlled.
- All club property categories, including office equipment and furniture, can be registered.
- Receipts, issues, returns, repairs, adjustments and disposals retain a traceable history.
- The Team Manager can perform approved day-to-day tasks without receiving unrelated financial or administrative powers.
- A Chairman-designated backup can perform only explicitly authorized inventory tasks.
- Stocktakes can be recorded quarterly and during season changes and handovers.
- Stocktake discrepancies remain traceable and do not silently overwrite inventory balances.
- Significant adjustments and disposals require independent review.
- A proposer or recorder cannot approve their own significant adjustment or disposal.
- Pending actions remain pending until reviewed by a separate authorized official.
- All authorized officials can export inventory reports without bypassing the permissions governing the underlying records.
- Sensitive fields remain excluded from exports unless the official is separately authorized to view them.
- Negative stock, unauthorized actions and invalid lifecycle transitions are rejected.
- Direct API access and cross-club access cannot bypass permissions.
- Private inventory data is absent from public pages and public-facing data views.
- Relevant actions, approvals and exports are auditable.
- The interface is usable on mobile devices and fails safely when authorization or connectivity is uncertain.

15. Decisions recorded and remaining design questions

15.1 Confirmed decisions

The following decisions have been confirmed for this design:

1. Backup maintainer: The Chairman designates an authorized backup inventory maintainer with explicitly scoped permissions.
2. Significant adjustments and disposals: A second authorized official must independently review them. The person who records or proposes an action cannot approve their own action.
3. Report exports: All authorized officials may export inventory reports, subject to their existing access permissions for the underlying records and fields.
4. Stocktake frequency: Quarterly stocktakes, plus checks at season changes and handovers.

These are design decisions only. They do not authorize implementation or changes to the database, security policies or deployment.

15.2 Remaining design questions

Resolve the following before implementation planning is approved:

1. Which categories use quantity tracking, individual tracking or a mix?
2. What kit sizes and units of measure should be available?
3. Which items require minimum-stock alerts, and what thresholds apply?
4. Which roles may see acquisition values, donor contacts, serial numbers, uplo

# Timau Union FC — Screen & Navigation Design (Draft)

**Status:** Wireframe specification only; no application code.

## Visual direction
- Mobile-first and professional for community football operations.
- Neutral palette with green accent proposed; club approves final colors.
- Use a placeholder crest until an approved asset is supplied.
- High contrast, large touch targets and clear loading/error/empty states.
- KSh amounts and Africa/Nairobi date/time display.
- Stack records on mobile; use tables on larger screens where useful.
- Print layouts hide navigation and exclude unauthorized fields.

## Navigation
Suggested mobile navigation: **Home · Fixtures · Squad · Updates · More**. More contains authorized modules such as Finance, Training, Transport, Welfare, Sponsors, Reports and Club Settings. Hidden navigation is not an authorization control.

## Screens
1. **Sign-in/invitation:** email sign-in, invite validation, expired/revoked recovery and clear explanation that leadership assigns roles.
2. **Role-aware home:** greeting, role, next fixture, availability prompt, pending tasks, latest approved announcement and finance summary only for authorized users. No invented totals.
3. **Fixtures:** upcoming/past fixtures, date, kickoff, opponent, competition, venue and status; detail view for availability, transport readiness, match-day checklist and result/report. Design T-7, T-3 and T+1 alerts. Mark unconfirmed facts clearly.
4. **Squad/availability:** operational player list, individual availability and selection state restricted to authorized staff. Players see their own information and permitted team details.
5. **Training/attendance:** sessions, attendance and authorized coaching notes; no welfare details in general coaching screens.
6. **Transport:** fixture-linked needs and confirmations. Distinguish requested, coordinated, confirmed and unresolved. Separate cost estimate, pledge, approval and payment. T-3 review highlights unresolved needs without implying funding exists.
7. **Finance:** categorized income/expenses, approved position, evidence and audit trail. Distinguish pledged, received, pending and approved. Opening balance remains pending until approval. Restrict records to authorized roles.
8. **Approval queue:** proposer, type, amount where applicable, evidence and submission date; confirm approve/reject actions and capture reasons.
9. **Welfare:** restricted list/detail, minimal sensitive data in list rows/notifications, no public indexing, broad export disabled by default.
10. **Sponsors/well-wishers:** support type, pledge, amount received, restrictions and acknowledgement. Publish names/logos only with permission and approval; do not promise unapproved bonuses.
11. **Media/announcements:** draft → preview → approval → publish/unpublish; public page shows published content only.
12. **Club management:** invite by email, assign/revoke roles, deactivate access and review invitations. Log role changes; no self-assignment.
13. **Reports:** date-filtered role-scoped reports, printable with club name, period, generated time and state labels. No private welfare details in general reports.
14. **Club Store catalogue:** public, mobile-friendly product cards with jersey/mesh image, item name, price, available sizes/colours, stock availability and optional name/number printing. Empty/out-of-stock states must be clear.
15. **Product detail/order:** choose size, colour, quantity and allowed personalization; collect only necessary customer contact and collection details; show order summary and total before submission.
16. **Payment choice/status:** customer selects M-Pesa or cash on collection. For M-Pesa, allow reference submission and display “Awaiting verification” until an authorized person confirms receipt. For cash, display “Due on collection” until staff records cash received. Never show an order as paid merely because it was submitted.
17. **Store management:** authorized store manager adds/edits products, variants, prices, stock and order status; stock changes require a reason and are audited. Show low-stock and out-of-stock indicators.
18. **Payment verification/sales:** treasurer or specifically authorized verifier reviews payment references, records cash received, and sees order totals, verified payments, cancellations/refunds and date-filtered sales reports. Keep sales/merchandise costs separately identified from other club funds.

## Club Store interaction states
- Keep order status (pending, confirmed, ready for collection, collected, cancelled) separate from payment status (unpaid, awaiting verification, verified/paid, failed or refunded).
- Show order reference and collection instructions after submission; do not promise a collection date until the club confirms it.
- Show sizes/variants and stock clearly; prevent ordering unavailable variants.
- The initial design supports manual M-Pesa verification and cash collection recording. Automated Daraja payment integration requires separate approval and security/reconciliation design.

## Accessibility and interaction
- Short forms with related fields grouped.
- Confirm irreversible/high-impact actions.
- Plain-language success/errors and preserve values after recoverable validation errors.
- Label inputs and show keyboard focus.
- Never rely on color alone for status.
- Design loading, offline/network and permission-denied states.

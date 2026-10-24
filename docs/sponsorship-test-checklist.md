# Public sponsorship — Parts 1–3 test checklist

## Database and security
- [ ] Review the single migration against the live schema before applying it.
- [ ] Anonymous visitors can execute submit_sponsor_enquiry but cannot SELECT or UPDATE sponsor_enquiries.
- [ ] Non-authorized authenticated roles cannot read or update enquiries.
- [ ] Test field length limits, invalid interest values, honeypot and minimum form dwell time.
- [ ] Public partner view exposes only approved records opted into the wall and only its defined public columns.
- [ ] No public page shows sponsor prices, private package details, private notes or contact fields.

## Public UI
- [ ] Partnership page cards and form work at 390px without horizontal overflow.
- [ ] WhatsApp and brochure destinations are configurable in js/sponsorship-config.js.
- [ ] Form shows accessible success and error states and validates on client and server.
- [ ] Partner wall includes only approved opt-in records; fan offer text only appears when enabled.
- [ ] All external website links use HTTP(S) and open safely.
- [ ] Existing management pages and Sponsor Lead tabs remain unchanged.

## Activation checkpoint
- [ ] Verify existing sponsor account creation and email invitation flow before adding activation.
- [ ] Enquiries tab uses existing Sponsor Lead / Platform Admin role checks.
- [ ] Activation reuses existing sponsor creation, approval and invitation; no parallel auth flow.

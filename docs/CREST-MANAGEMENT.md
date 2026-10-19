Timau Union FC — Crest Management

Last updated: 19 October 2026

1. Purpose

This document defines how the Timau Union FC club crest is stored, approved, displayed and maintained across the public website and any future private management application.

The crest represents the club's identity. The asset currently integrated into the website has been designated by the project owner for use as the club crest, and its display has been verified by the project owner.

This document describes the management process. It does not implement crest uploads, an administration interface, database changes or new application features.

2. Current status

Status: Crest integrated and displaying correctly on the published Phase 1 website, as verified by the project owner.

Current asset:

"assets/club-crest.jpg"

The crest is referenced by the public website and member-access placeholder. The project owner has confirmed that it displays correctly.

Verified

- [x] Crest asset is present at "assets/club-crest.jpg".
- [x] Crest is integrated into the public website.
- [x] Crest is integrated into the member-access placeholder.
- [x] The project owner confirmed that the crest displays correctly.
- [x] The member-access page path was corrected and "/app/" loads.
- [x] The live website uses the approved GitHub "main" → GitHub Pages deployment path.

Remaining governance and maintenance actions

- [ ] Record any separate formal club-authority approval or artwork-use permission if required by the club's governance process and not already documented.
- [ ] Include the crest in any future review of public-facing content with club officials.
- [ ] Record further visual or technical test results only when those checks have actually been performed.

Do not describe the integrated "club-crest.jpg" as a temporary concept asset. If the club later authorises a different official version, follow the change-control process in Section 6.

3. Approved use

The currently integrated crest may be displayed in the website locations already implemented:

- Public website header.
- Public website favicon.
- Public website footer, where included.

Any use in additional club materials must be separately authorised where required.

Keep the crest consistent across the website. Do not create unrelated variants, distort its proportions or change its official colours without authorisation.

The website's visual theme uses red, white and black, with yellow highlights. These interface colours must not be assumed to replace or redefine the crest's own colours.

4. Asset requirements

The current website asset is a JPEG image. Keep using it unless an authorised replacement is approved and tested.

For any future replacement, suitable formats may include:

Format| Recommended use
SVG| Scalable website logo or favicon, if supplied artwork is suitable and sanitised
PNG| Raster logo, including transparency where supported by the artwork
JPEG| Existing raster artwork where a solid background is appropriate
WebP| Optional web-optimised raster image where appropriate

For all assets:

- Preserve the crest's aspect ratio.
- Ensure sufficient contrast against the backgrounds where it appears.
- Keep the logo recognisable at small sizes.
- Avoid unnecessarily large image files.
- Do not stretch, crop or recolour artwork in a way that changes the club identity.
- Keep an original approved copy available in the project's version history or other authorised source.

Review SVG files before publication. Remove scripts, embedded event handlers, unexpected external references and other unnecessary active content.

5. File naming and storage

Current public asset path:

"assets/club-crest.jpg"

Current project organisation includes:

assets/
  club-crest.jpg

docs/
  CREST-MANAGEMENT.md
  IMPLEMENTATION-STATUS.md

If the crest is replaced with another file format or filename, update all relevant logo and favicon references consistently. Check relative paths for both the site root and the "/app/" page so that no broken image paths are introduced.

Do not store confidential documents, private contact information or account credentials in the public assets directory.

6. Approval and change control

Use this process whenever the crest is replaced or materially modified:

1. Receive: Obtain the proposed artwork from an authorised club representative.
2. Confirm: Verify that it is intended for official club use and that the club has permission to publish it.
3. Review: Check file integrity, appearance, accessibility and suitability for web use.
4. Approve: Obtain confirmation from the Chairman or an explicitly authorised delegate, where required by the club's governance process.
5. Replace: Update the asset and references in the approved source branch.
6. Test: Check the header, favicon, footer and responsive layouts, including the "/app/" page.
7. Release: Publish through the approved GitHub "main" → GitHub Pages workflow.
8. Verify: Open the published website and confirm that the correct asset loads.
9. Record: Update this document and "docs/IMPLEMENTATION-STATUS.md" to reflect what was actually changed and verified.

Do not replace the current crest based solely on an unverified message, an unapproved design proposal or an asset supplied without permission. A future replacement requires review and approval; it is not implied by this document.

7. Security and privacy

The public crest is a public asset, not a secret.

However:

- Do not expose private storage credentials or access tokens when handling crest files.
- Do not add Supabase service-role keys or other secrets to the website repository.
- Do not introduce an unrestricted public upload endpoint.
- Do not allow unauthorised users to replace the official asset.
- Do not assume that hiding an upload control protects an asset-management operation.
- If a future management feature supports uploads, require authentication, explicit permissions, file validation and appropriate storage policies.
- Keep the current static website independent of any future private crest-management functionality.

Any future upload system must be separately scoped, reviewed and explicitly approved before implementation.

8. Website integration checks

The following items are confirmed by the project owner:

- [x] The crest asset is integrated into the website.
- [x] The crest displays correctly on the published site.
- [x] The crest is used on the member-access placeholder.
- [x] The deployed member-access path "/app/" loads correctly.

The following checks have not been separately recorded and should only be marked complete after they are performed:

- [ ] Confirm all favicon references load correctly in target browsers.
- [ ] Check the crest's legibility across relevant light and dark backgrounds.
- [ ] Check image quality and aspect ratio on a range of mobile and desktop sizes.
- [ ] Inspect browser console and network errors for broken resources.
- [ ] Confirm any additional accessibility or visual test results.

GitHub Pages paths may behave differently from local file paths. Test the deployed site rather than relying only on a local preview.

9. Rollback

If the crest causes rendering problems or is found to be incorrect:

1. Stop further publication of the affected change.
2. Restore the last known-good authorised asset through Git version control.
3. Restore any related references that were changed.
4. Test the website in the approved review environment.
5. Publish through the authorised GitHub Pages workflow.
6. Verify the restored crest on the live website.

Do not delete repository history or rewrite unrelated files to correct a crest problem.

10. Scope limitations

This document does not authorise:

- Supabase migrations or database changes.
- Authentication or permission changes.
- A crest upload or administration interface.
- Changes to the approved public/private application separation.
- A hosting-provider change.
- Publication of branding that has not been authorised.

Any such work requires its own reviewed scope and explicit approval.

11. Completion criteria

Crest integration for Phase 1 is complete based on the project owner's confirmation that the crest is integrated and displaying correctly.

Future crest changes should only be considered complete when:

- The proposed artwork has been supplied by an authorised source.
- Required club approval and usage permission have been confirmed.
- The asset is stored in the correct project location.
- Logo and favicon references work.
- Relevant mobile and desktop presentation checks have been completed.
- The published GitHub Pages site has been verified.
- This document and the implementation status reflect the actual results.

Current decision: Keep "assets/club-crest.jpg" in use. It is integrated and displaying correctly as confirmed by the project owner. Formal approval of public-facing website content remains a separate outstanding project action. Do not add upload functionality or change the hosting, authentication or database configuration as part of crest management.

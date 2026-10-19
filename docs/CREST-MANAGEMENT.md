
# Timau Union FC — Crest Management

Last updated: 19 October 2026

## 1. Purpose

This document defines how the Timau Union FC club crest should be supplied, approved, stored and displayed across the public website and future private management application.

The crest represents the club's identity. Only an authorised, approved version should be used as the official club logo.

This document describes the management process. It does not implement crest uploads, an administration interface, database changes or new application features.

## 2. Current status

**Status: Temporary concept crest included in the Phase 1 source package.**

The current file is:

`assets/club-crest.svg`

It is a temporary design asset and must not be represented as the club's officially approved crest until club officials confirm it.

### Outstanding actions

- [ ] Obtain the official crest from an authorised club representative.
- [ ] Confirm that the club has permission to use the supplied artwork.
- [ ] Obtain approval from the Chairman or an explicitly authorised delegate.
- [ ] Check the image quality, colours, proportions and readability.
- [ ] Replace the temporary concept asset after approval.
- [ ] Test the approved crest on mobile and desktop.
- [ ] Verify the favicon and all logo references.
- [ ] Confirm that the published website displays the approved version.

Until approval is complete, the concept artwork must be treated as a placeholder.

## 3. Approved use

The approved crest may be displayed in the following locations, once supplied and authorised:

- Public website header.
- Public website favicon.
- Public website footer, where appropriate.
- Future club materials that have been separately approved.

The crest should remain consistent across the website. Do not create unrelated variants, distort its proportions or change its official colours without authorisation.

The visual theme may use the club's approved red, white and black palette, with yellow highlights where appropriate. These interface colours must not be assumed to replace the crest's official colours.

## 4. Recommended asset formats

Prefer the following formats:

| Format | Recommended use |
|---|---|
| SVG | Website logo and favicon where the supplied artwork is suitable and sanitised |
| PNG | Transparent-background logo and compatibility fallback |
| WebP | Optional web-optimised raster image where appropriate |

### Asset requirements

- Preserve the crest's aspect ratio.
- Use a transparent background when the official artwork supports it.
- Ensure sufficient contrast against light and dark backgrounds.
- Keep the logo recognisable at small sizes.
- Avoid unnecessary large image files.
- Do not stretch, crop or recolour the artwork in a way that changes the official identity.
- Keep a clean, approved original separately from any web-optimised copies.

SVG files should be reviewed before publication. Remove scripts, embedded event handlers, unexpected external references and other unnecessary active content.

## 5. File naming and storage

For the current static website, the expected public asset path is:

`assets/club-crest.svg`

If an approved replacement is provided in SVG format, it may replace this file after review and approval.

If the official asset is supplied in another format, update the relevant website references consistently rather than leaving broken image or favicon paths.

Recommended project organisation:

```text
assets/
  club-crest.svg
  # Optional approved raster alternatives, if needed

docs/
  CREST-MANAGEMENT.md
  IMPLEMENTATION-STATUS.md
```

Do not store confidential documents, private contact information or account credentials in the public assets directory.

## 6. Approval and change control

Use this process whenever the crest is replaced or modified:

1. **Receive:** Obtain the artwork from an authorised club representative.
2. **Confirm:** Verify that the artwork is intended for official club use and that the club has permission to publish it.
3. **Review:** Check file integrity, appearance, accessibility and suitability for web use.
4. **Approve:** Obtain confirmation from the Chairman or an explicitly authorised delegate.
5. **Replace:** Update the relevant asset and references in the approved source branch.
6. **Test:** Check the header, favicon, footer and responsive layouts.
7. **Release:** Publish through the approved GitHub `main` → GitHub Pages workflow.
8. **Verify:** Open the published site and confirm that the correct asset loads.
9. **Record:** Document the change, approval date and source of the artwork without publishing unnecessary personal information.

Do not replace the official crest based solely on an unverified message, an unapproved design proposal or an asset supplied without permission.

## 7. Security and privacy

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

## 8. Website integration checks

After replacing the asset, verify:

- [ ] The header logo loads without errors.
- [ ] The logo links to the public homepage, where intended.
- [ ] The favicon loads correctly.
- [ ] The logo is legible on the website's light and dark backgrounds.
- [ ] The image does not appear stretched or pixelated.
- [ ] Alternative text identifies the club meaningfully.
- [ ] The asset path works on the deployed GitHub Pages website.
- [ ] No unrelated page layouts or permissions have changed.
- [ ] No new console errors or broken resources have been introduced.

GitHub Pages paths may behave differently from local file paths. Test the deployed site rather than relying only on a local preview.

## 9. Rollback

If an approved crest causes rendering problems or is found to be incorrect:

1. Stop further publication of the affected change.
2. Restore the last known-good approved asset through Git version control.
3. Restore any related references that were changed.
4. Test the website locally or in the approved review environment.
5. Publish through the authorised GitHub Pages workflow.
6. Verify the restored crest on the live website.

Do not delete repository history or rewrite unrelated files to correct a crest problem.

## 10. Scope limitations

This document does not authorise:

- Supabase migrations or database changes.
- Authentication or permission changes.
- A crest upload or administration interface.
- Changes to the approved public/private application separation.
- A hosting-provider change.
- Publication of unapproved club branding.

Any such work requires its own reviewed scope and explicit approval.

## 11. Completion criteria

Crest management is considered complete for Phase 1 when:

- The club's authorised representative has supplied the intended official crest.
- The appropriate club authority has approved its use.
- The approved asset is stored in the correct project location.
- Website logo and favicon references work.
- Mobile and desktop presentation have been checked.
- The published GitHub Pages site has been verified.
- The implementation status document reflects the actual results.

**Current decision:** Keep the existing concept crest clearly identified as temporary until the official artwork is supplied and approved.

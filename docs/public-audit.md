# Public Repository Audit

Date: 2026-05-11

## Audience Impression

PortPirate now presents as a focused native macOS developer utility instead of an internal preview dump. The README leads with the product, download path, trust posture, and practical workflow before developer commands.

## What Improved

- Added a visible GitHub Markdown tip alert at the top of the README.
- Linked CI and release badges to the relevant GitHub surfaces.
- Added the real menu bar panel screenshot as a rounded GitHub README showcase.
- Moved preview signing and notarization limitations into a clear trust note.
- Added CONTRIBUTING and SECURITY files for GitHub community profile coverage.
- Added issue forms and a pull request template so external feedback arrives with usable context.
- Added Dependabot monitoring for GitHub Actions.
- Hardened workflows with explicit permissions, concurrency, and job timeouts.

## Remaining Public Risks

- The release pipeline now signs, notarizes, staples, and validates the DMG when release signing and notarization secrets are configured. Activation still depends on setting `PORTPIRATE_NOTARY_ENABLED=true` with the required Apple credentials.
- A short demo clip would make the interaction model clearer than a screenshot alone.
- The release page should keep using clear notes with Highlights, Fixed, Improved, PRs, and Known Limitations.
- A Homebrew Cask would make installation feel more mature once notarization is in place.

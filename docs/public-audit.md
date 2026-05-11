# Public Repository Audit

Date: 2026-05-11

## Audience Impression

MacDev now presents as a focused native macOS developer utility instead of an internal preview dump. The README leads with the product, download path, trust posture, and practical workflow before developer commands.

## What Improved

- Added a visible GitHub Markdown tip alert at the top of the README.
- Linked CI and release badges to the relevant GitHub surfaces.
- Moved preview signing and notarization limitations into a clear trust note.
- Added CONTRIBUTING and SECURITY files for GitHub community profile coverage.
- Added issue forms and a pull request template so external feedback arrives with usable context.
- Added Dependabot monitoring for GitHub Actions.
- Hardened workflows with explicit permissions, concurrency, and job timeouts.

## Remaining Public Risks

- Preview releases are still ad-hoc signed and not notarized.
- README would be stronger with screenshots or a short demo clip.
- The release page should keep using clear notes with Highlights, Fixed, Improved, PRs, and Known Limitations.
- A Homebrew Cask would make installation feel more mature once notarization is in place.

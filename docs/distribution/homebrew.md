# Homebrew Cask Distribution

PortPirate will be distributed via Homebrew Cask once Developer ID signing and notarization are live. Until then this document tracks what is prepared and what is blocked.

## Status

- ✅ Cask file drafted at `Casks/portpirate.rb`.
- ⏳ Blocked on **Apple Developer Program enrollment** (and the resulting Developer ID Application certificate).
- ⏳ Blocked on **notarization** being run on a tagged release (the release pipeline already supports it; needs the secrets set in the GitHub repo).
- ⏳ Blocked on at least one **signed + notarized DMG** being published to GitHub Releases so we have a real `sha256` for the Cask.

## Submission Path

We deliberately submit to **homebrew-cask** (the main Homebrew tap) once we are signed + notarized, not to a private tap. Reason: a private tap signals "weird side project"; the main tap signals "real macOS app". The acceptance criteria for the main tap are exactly the things we have to do anyway for a paid release.

### Acceptance criteria (homebrew-cask)

1. The cask installs an `.app` that is **code-signed with Developer ID** and **notarized + stapled**.
2. The cask uses an **HTTPS download URL on a stable host** (GitHub Releases is fine).
3. `sha256` matches the artifact exactly.
4. The app has a **homepage** and a non-trivial **desc**.
5. `livecheck` resolves to the latest stable release.
6. The cask passes `brew style --fix` and `brew audit --new --cask portpirate`.

### Steps once unblocked

```bash
# 1. Verify a signed+notarized release is published
gh release view v<version>
xcrun stapler validate dist/PortPirate-<version>.dmg

# 2. Update Casks/portpirate.rb
#    - version
#    - sha256 of the released DMG:
shasum -a 256 dist/PortPirate-<version>.dmg

# 3. Local audit before submission
brew install --cask --no-quarantine ./Casks/portpirate.rb
brew uninstall --cask portpirate
brew style --fix ./Casks/portpirate.rb
brew audit --new --cask ./Casks/portpirate.rb

# 4. Submit
#    - fork github.com/Homebrew/homebrew-cask
#    - copy Casks/portpirate.rb to homebrew-cask/Casks/p/portpirate.rb
#    - open PR with the title "portpirate <version> (new cask)"
```

The Cask file in this repo stays the source of truth; the homebrew-cask PR is a copy of it. Future version bumps happen by maintainer-bot or a small follow-up PR.

## Why not a third-party Cask tap?

We could publish a private tap (`brew tap jx-grxf/portpirate`) instantly and bypass all of the above. We won't, because:

- It doesn't reach `brew search portpirate`, so discovery suffers.
- Users have to add a tap they have never heard of, which is exactly the trust hurdle we are trying to clear.
- Once we are signed + notarized, the main tap accepts us — there is no reason to live in a private tap permanently.

A private tap is only worth it as a *preview channel* for beta DMGs, and even there the Sparkle beta feed already solves the problem.

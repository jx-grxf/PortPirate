# ADR 003 — Licensing

Status: Accepted
Date: 2026-05-26

## Context

PortPirate is currently MIT-licensed (`LICENSE`), built in public, and intended to become a paid macOS app. Before the first paid release we have to settle the question that blocks every commercial OSS project: how do we keep the code visible to potential users and contributors, while preventing a competitor from forking the repo, slapping a different name on it, and selling the same binary on the App Store?

The realistic options are:

1. **Stay MIT.** Free reuse and rebranding. Hard to defend pricing because anyone can ship the same thing for free.
2. **AGPL-3.0.** Strong copyleft, network clause. Doesn't actually stop a competitor from selling — it just forces them to publish source.
3. **Source-available, non-commercial (e.g. PolyForm Noncommercial, Elastic License v2).** Code stays readable, commercial use requires a paid license. Often clumsy to consume and discourages drive-by contributors.
4. **Fair Source / Functional Source License (FSL-1.1-MIT).** Source-available with a non-compete window; auto-converts to MIT (or Apache-2.0) after two years. Originated by Sentry, adopted by Keygen and others.
5. **Closed binary, proprietary EULA.** Cleanest commercial story, but throws away the trust the public repo has built and breaks the existing showcase / contribution flow.

## Decision

Adopt **FSL-1.1-MIT** for application source going forward. The two-year auto-conversion to MIT keeps the repo honest with the "build in public" pitch (everything we ship eventually becomes truly open source) while giving us a defensible window to monetize without immediate clones.

Concrete shape:

- `LICENSE` switches from MIT to FSL-1.1-MIT effective on the first FSL-tagged release. Each release of PortPirate carries the FSL of *its release date*; commits older than two years from "today" are MIT automatically per the FSL terms.
- `LICENSE-MIT-LEGACY` retains the original MIT header to honor pre-switch contributions.
- The README "License" section becomes the plain-English explainer with a link to the FSL upstream FAQ. We deliberately do **not** add a separate `LICENSING.md` — one source of truth is easier to keep current than two.
- `CONTRIBUTING.md` is updated: contributions are accepted under FSL-1.1-MIT going forward; contributors retain copyright; no CLA. (We can revisit a CLA later if we ever take outside investment, but not for the initial paid release.)
- `README.md` keeps "open source eventually" framing — the badge moves from MIT to FSL.

## Why not the alternatives

- **MIT alone**: no commercial defense. Forks are inevitable, support burden lands on us, pricing collapses.
- **AGPL**: forces source disclosure on derivatives but does not stop a paid competing fork. The license is also widely blocked by enterprise software policies, which would shrink the addressable market later.
- **PolyForm / Elastic**: source-available but with permanent commercial restriction. Loses the "trust" property — contributors and reviewers see a license they have to lawyer through. Real-world adoption is much smaller than FSL.
- **Closed binary**: kills the agent-attribution / stack-grouping story that depends on people being able to *read the code* and trust what it does to their machine. Closed source for a tool that walks the process tree and reads env vars is a hard sell.

## Implications

- Homebrew Cask submission stays clean: Cask metadata only cares about the binary distribution license, and FSL-licensed apps are accepted.
- App Store distribution is not blocked — Apple's review concerns binary content and entitlements, not source license.
- Pricing is now defensible: free tier without Workspace Stacks v2 / Smart Actions / stale auto-sweep; paid lifetime or yearly license. The license itself doesn't enforce the gate (the code does that), but it prevents a trivial fork-and-resell from undercutting us within the non-compete window.
- We do *not* relicense old commits retroactively beyond what FSL itself does (auto-MIT after 2 years). Anything already published under MIT stays available under MIT to anyone who fetched it.

## Open follow-ups

- Add `LICENSE` (FSL-1.1-MIT text) and `LICENSE-MIT-LEGACY` to the repo as part of the licensing-switch PR.
- Update `LICENSING.md`, `CONTRIBUTING.md`, `README.md`, and the Cask description in the same change so the messaging stays coherent.
- Decide whether the macOS app binary needs an embedded `Credits.rtf` / Settings-Acknowledgements view linking to FSL. Probably yes for App Store, optional for direct download.

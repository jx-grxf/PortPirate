# PortPirate Architecture

This document describes how PortPirate is put together: the modules, the data flow from a kernel syscall to a pixel on screen, the threading model, and the rules every layer follows. It is meant for contributors and for the curious — if a section is wrong, that is a bug worth fixing.

For decisions that shaped the architecture (agent attribution model, workspace stacks scope, licensing), see the ADRs in [`docs/`](docs/).

---

## Module layout

PortPirate is a Swift Package with two targets:

```
Sources/
├── PortPirateApp/        ← thin SwiftUI entry point (App + Settings + windows)
└── PortPirateCore/       ← all of the actual logic, headlessly testable
    ├── Models/           ← value types, no behavior, all Sendable
    ├── Services/         ← discovery, classification, control, updates
    ├── Stores/           ← long-lived state (AppState, ProfileStore)
    ├── Support/          ← AppKit helpers (window focus)
    └── Views/            ← SwiftUI views
Tests/
└── PortPirateCoreTests/  ← 50+ unit and integration tests against Core
```

Everything that can be tested without `MenuBarExtra` lives in `PortPirateCore`. The app target is a SwiftUI shell. This is the single biggest reason the test suite stays honest — `Core` has no AppKit dependencies in its hot paths.

---

## Data flow: from `lsof` to a pixel

```
   ┌───────────────────────┐
   │ User clicks menu icon │
   └───────────┬───────────┘
               │
               ▼
   ┌───────────────────────┐
   │ AppState.bootstrap() │  @MainActor
   │  - load profiles     │
   │  - start refresh tick│
   └───────────┬───────────┘
               │
               ▼  every refreshInterval seconds
   ┌─────────────────────────────────────┐
   │ DiscoveryService.scan()             │  actor
   │  ├─ PortScanner.scan()              │  → [PortEndpoint]   (lsof -F)
   │  ├─ ProcessInspector.inspect(pids)  │  → [PortPirateProcess]
   │  │    ├─ /bin/ps for command/user   │
   │  │    └─ lsof -d cwd  for cwd       │
   │  ├─ for each PID, cached:           │
   │  │   ├─ ProcessInspector.context()  │  → ProcessContext   (proc_pidinfo + KERN_PROCARGS2)
   │  │   ├─ AgentDetector.classify()    │  → ProcessOwner
   │  │   └─ GitContextResolver.resolve()│  → GitContext?
   │  ├─ RuntimeClassifier.classify()    │  → RuntimeKind
   │  └─ LaunchdInspector.userAgents()   │  → [LaunchAgentInfo]   (opt-in)
   └─────────────────┬───────────────────┘
                     │
                     ▼
   ┌─────────────────────────────┐
   │ AppState.servers = ...      │  @MainActor (assigned on main)
   │  derived properties:        │
   │   developerServers          │  filtered by isPrimaryRuntime
   │   backgroundServers         │  → other listeners
   │   editorHelperServers       │  → VS Code / Cursor / Zed / JB helpers
   │   appleServiceServers       │  → AirPlay, system services
   │   visibleDeveloperServers   │  → developerServers after filter chips
   │   groupedDeveloperServers   │  → StackGrouper.group(...)
   └─────────────────┬───────────┘
                     │
                     ▼
   ┌───────────────────────────────────┐
   │ MenuBarPanelView                  │  SwiftUI
   │  ├─ filterChips (AI / Stale)      │
   │  ├─ ForEach stacks → StackCardView│
   │  ├─ ForEach ungrouped → ServerRow │
   │  ├─ backgroundSection             │  collapsed
   │  ├─ editorHelpersSection          │  collapsed
   │  └─ appleServicesSection          │  collapsed
   └───────────────────────────────────┘
```

A single refresh tick fans out, gathers everything, then assigns once on `@MainActor`. The view re-renders from the new snapshot. There is no streaming, no diff, no incremental update — simplicity is the feature.

---

## The discovery pipeline in detail

### 1. PortScanner

Wraps `/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -Fcpn` and parses the output (the field-based form is more stable than the human-readable one). Output: `[PortEndpoint]` where each endpoint is `(processID, processName, address, port)`. One process listening on multiple addresses produces multiple endpoints; the grouping happens later.

### 2. ProcessInspector (actor)

Two public methods, both async:

- `inspect(processIDs:)` → `[Int32: PortPirateProcess]`. Calls `/bin/ps -o pid,ppid,user,command` for the requested PIDs, then `lsof -d cwd -Fpn` to attach working directories. This is the cheap pass — it runs for every listener every tick.
- `context(for:)` → `ProcessContext?`. The expensive pass, called only once per PID and then cached. Uses real macOS syscalls, no shell:
  - `proc_pidinfo(PROC_PIDTBSDINFO)` — parent PID, start time.
  - `proc_pidinfo(PROC_PIDVNODEPATHINFO)` — cwd path (direct, no `lsof`).
  - `KERN_PROCARGS2` via `sysctl` — argv array and environment.
  - `proc_pidpath` — executable path.
  - `parentChain(of:limit: 32)` — walks `ppid` up to launchd or a cycle, max 32 hops.

Environment is filtered to a whitelist of prefixes that PortPirate actually keys on (`CLAUDE_*`, `CURSOR_*`, `CODEX_*`, `OPENCODE_*`, `AIDER_*`, `GEMINI_CLI_*`, `COPILOT_*`, `AUGMENT_*`, `QWEN_CODE_*`, `ANTHROPIC_*`, `OPENAI_*`, `npm_*`, `VSCODE_*`, plus three single keys `CLAUDECODE`, `AI_AGENT`, `TERM_PROGRAM`). Nothing else is read or retained. See [ADR-001](docs/adr-001-agent-attribution.md).

### 3. AgentDetector (Sendable struct)

Takes a `ProcessContext`, returns a `ProcessOwner`. Three signals tried in order:

1. **Env vars** (filled badge) — exact prefix or key match in `envSubset`.
2. **Argv basename** (dashed badge with `~`) — `URL(fileURLWithPath: argv[i]).lastPathComponent` matched against an allowlist. Not substring matching — substring matching was the previous implementation and produced false positives on paths like `/Users/claude/project`.
3. **Parent executable** (outlined badge) — `parentChain` resolved to executable basenames, matched against substrings of known agent names. VS Code / Code Insiders are deliberately *not* mapped to an AI agent here, only to themselves.

When none matches but the parent is an interactive shell (`bash`, `zsh`, `fish`), the owner is `.manual`. Otherwise `.unknown`. The chosen detection channel is carried back as `ProcessOwner.aiAgent(kind:, sessionID:, source:)` so the UI can render confidence visually instead of overclaiming.

### 4. GitContextResolver (Sendable struct)

Pure filesystem reads, no `git` subprocess:

- Walks upward from the cwd looking for `.git`.
- If `.git` is a directory: reads `.git/HEAD`, extracts `refs/heads/<branch>` or the detached SHA. `repoRoot` is the directory containing `.git`.
- If `.git` is a file (worktree): reads `gitdir: <path>` from the file, follows it to the worktree's own git directory, reads `HEAD` there. Flags `isWorktree = true`. The worktree's working directory remains the `repoRoot`; the dereferenced git directory is internal.

No `git` subprocess in the hot path was a hard requirement — see [ADR-001 "Why not shell-out"](docs/adr-001-agent-attribution.md). Cold-starting `git` per PID per tick is the polling cost we are explicitly positioning against.

### 5. DiscoveryService (actor)

Orchestrates the four pieces above. Holds `detectionCache: [pid_t: ProcessDetection]`. On every `scan()`:

1. Compute the current PID set.
2. Drop cache entries for PIDs that disappeared.
3. For each PID without a cache entry: build `ProcessContext`, classify, resolve git. Cache the tuple `(owner, gitContext, startedAt)`.
4. Apply `RuntimeClassifier` and `LaunchdInspector` and return a `DiscoverySnapshot`.

The cache is the reason agent classification does not re-walk the parent chain on every refresh — `ProcessContext` construction is the expensive part, classification itself is cheap.

### 6. RuntimeClassifier (pure)

Heuristics on `(processName, command, port, currentDirectory)` to label a listener as Vite, Next, Astro, Nuxt, Docker, Homebrew, AirPlay, etc. Drives the row icon and the "primary runtime" filter. Pure switch-on-strings code, exhaustively tested in `RuntimeClassifierTests`.

### 7. StackGrouper (pure)

Groups `[ListeningServer]` into `[WorkspaceStack]` by their `gitContext.worktreePath ?? repoRoot`. A group becomes a stack at ≥2 services; singletons fall back to ungrouped. Worktrees group on their own path so concurrent agent worktrees stay visually distinct. Mixed-branch stacks surface a warning instead of arbitrarily picking one branch.

Pure function (`GroupedServers` is just two arrays). All tests live in `StackGrouperTests`.

---

## State and concurrency

```
@MainActor             actor                   actor               Sendable
┌──────────┐    awaits    ┌─────────────────┐   awaits   ┌──────────────┐   uses   ┌──────────────────┐
│ AppState │ ───────────▶ │ DiscoveryService│ ────────▶ │ ProcessInspector│ ──────▶ │ AgentDetector    │
└──────────┘              └─────────────────┘            └──────────────┘            │ GitContextResolver│
                                                                                     └──────────────────┘
```

Rules:

- **`AppState`** is `@MainActor` and `@Observable`. SwiftUI reads its derived properties directly; only the main actor mutates the snapshot fields. There is no `ObservableObject`-style publisher plumbing.
- **`DiscoveryService` and `ProcessInspector`** are actors. They serialize concurrent calls to themselves and shed the surrounding contention. The cache lives inside `DiscoveryService` and is therefore single-writer by construction.
- **`AgentDetector` and `GitContextResolver`** are `Sendable` structs. They take a snapshot in, return a value out, and capture no state. Easy to test, easy to inject a mock parent-executable lookup.
- **`@nonisolated static`** is used on `AppState.isAIAgent(_:)` and `AppState.isStale(_:now:)` because filter predicates need to be called from sort closures without round-tripping the main actor.

There is no `Combine` and no `async let` fanout in the hot path. The pipeline is sequential because it is fast enough — a full scan with cache warm is well under 50 ms on a developer machine.

---

## Process control

`ProcessController` provides the destructive side of the app. Two entry points:

- `stop(processID:, force:)` — for listeners discovered by the scanner. `force = false` sends SIGTERM, `force = true` sends SIGKILL.
- `startScript(profile:, script:, ...)` — for `package.json` scripts launched from a `WorkspaceProfile`. Spawned via `Process()` with a filtered environment and live stdout/stderr capture.

Before any `kill` actually fires, `AppState.validatedStopTarget(for:)` re-runs the scan and confirms:

1. The listener is still a primary runtime (no system services).
2. The owning user matches the current user.
3. The port + PID combination still exists.
4. The command and cwd have not changed since the row was rendered.

If anything diverges, the stop is refused with `ProcessControllerError.unsafeProcess` and the error surfaces in the panel. This is what prevents the "Stop" button from killing whatever PID happens to occupy the slot after a crash + respawn race.

`AppState.stopStack(_:)` iterates members sequentially in port order. Sequential is on purpose: v1 has no dependency graph, so the safest default is a deterministic kill order. Smart Actions (planned, not yet built) will replace the kill loop with kind-aware shutdown (`docker stop`, `brew services stop`, `launchctl unload`, `SIGINT → SIGTERM → SIGKILL`).

---

## UI shell

```
PortPirateApp
├── MenuBarExtra("PortPirate") → MenuBarPanelView (the popover)
├── Window("Runtime Browser") → RuntimeBrowserView   (opt-in detail window)
└── Settings → SettingsView
```

### MenuBarPanelView

The popover is the primary surface. Top-to-bottom structure:

- **Header**: status dot, name, summary line ("7 active, 3 other"), refresh button.
- **Diagnosis bar**: text field for ad-hoc port lookup.
- **Local runtimes** (always expanded):
  - Filter chips (`AI agents`, `Stale >30m`) — only shown when at least one matching server exists.
  - **Stack cards** for every multi-service repo (StackCardView with disclosure).
  - **Ungrouped server rows** for singleton listeners.
  - Diagnostic card (when a port is diagnosed).
- **Other listeners** (disclosure, collapsed by default): legit dev procs that are not "primary runtimes" by RuntimeClassifier.
- **Editor helpers** (disclosure, collapsed by default): VS Code / Cursor / Windsurf / Zed / JetBrains helpers.
- **Apple services** (disclosure, opt-in via Settings).
- **Tools** (disclosure): workspaces, user launchd agents, managed script logs.
- **Footer**: Settings, Runtime Browser, Quit.

### Atom components (`Views/Rows.swift`)

- `ServerRowView` — the canonical row. Icon, title + port + owner badge, secondary line (`repo · branch · 18m` when git context + start time are available, fallback to the cwd basename otherwise), open / diagnose / stop buttons.
- `StackCardView` — disclosure wrapping a group of `ServerRowView`s. Header shows stack name, branch (or `mixed branches` warning), worktree marker, service count, and a "Stop all" button.
- `OwnerBadge` + `OwnerPresentation` — the agent-attribution capsule. Style is computed from `DetectionSource`:
  - `.env` → filled capsule (high confidence)
  - `.parentChain` → outlined capsule
  - `.argv` → dashed border + `~` prefix (likely)
- `FilterChip` — toggle for the two filter chips. Session state, not persisted.
- `RelativeAge.short` — formats a `Date?` into `5s` / `1m` / `3h` / `2d`. Pure, tested.

### DesignSystem

Spacing tokens (`Theme.s1`–`s6`), corner radii, animations, and the `glassCard()` / `glassInteractive()` view modifiers. On macOS 26+ those modifiers use the native `glassEffect(...)`; on older versions they fall back to a background + stroke.

### RuntimeBrowserView

Optional second window for fuller browsing. Not the primary surface — most users will only ever see the popover.

### SettingsView

Standard `Settings` scene. Controls workspaces, notifications, refresh interval, update channel, "show Apple services", "confirm force kill", etc. Persisted via `UserDefaults`.

---

## Background services

### NotificationService

Wraps `UNUserNotificationCenter`. Handles authorization, scan-failure notifications, port-collision notifications, expected-port-missing notifications, and managed-process-exit notifications. Settings UI gates which categories fire.

### UpdateService (Sparkle)

Wraps `SPUStandardUpdaterController` when Sparkle public/private keys are configured at build time. Channel selection (`stable` / `beta`) is read from `AppState.updateChannel` via a closure so it can change at runtime without re-creating the controller. The release pipeline writes the appcast.

### ProfileStore

Persistence for `[WorkspaceProfile]`. Plain JSON file under Application Support. Atomic write, deterministic ordering.

---

## Release pipeline

Two GitHub Actions workflows:

- `ci.yml` — runs `audit_release_identity.sh`, `swift build`, `swift test`, builds and signs the preview app bundle. Runs on every push and PR.
- `release.yml` — fires on tags. Builds the app, packages a DMG (`script/package_dmg.sh`), produces Sparkle ZIP + appcast (`script/create_sparkle_assets.sh`), runs `verify_appcast.swift` against the expected download URL, optionally notarizes + staples + validates when `PORTPIRATE_NOTARY_ENABLED == 'true'`, attaches everything to the GitHub Release, and pokes a website deploy hook.

Release runbook: [`docs/release.md`](docs/release.md).
Homebrew submission plan: [`docs/distribution/homebrew.md`](docs/distribution/homebrew.md).

---

## What lives where (cheat sheet)

| You want to change... | Look at |
|---|---|
| Which env keys mark a Claude/Cursor/Codex session | `AgentDetector.swift`, `ProcessInspector.filteredEnvironment` |
| How parent processes are walked | `ProcessInspector.parentChain` |
| How worktrees are detected | `GitContextResolver.swift` |
| What a Vite/Next/Astro listener looks like | `RuntimeClassifier.swift` |
| How servers group into stacks | `StackGrouper.swift` |
| The owner-badge appearance | `OwnerBadge` in `Views/Rows.swift` |
| The filter chips | `FilterChip` + `AppState.filter*` |
| Adding a new section to the panel | `MenuBarPanelView.swift` |
| Adding a new setting | `AppState.swift` (property + Defaults key) + `SettingsView.swift` |
| How safe-stop validates | `AppState.validatedStopTarget` |
| Notification triggers | `NotificationService` + `AppState.sendStateNotifications` |
| Sparkle behavior | `UpdateService.swift` |

---

## Invariants worth knowing

- **The cache invalidates when the PID is gone, never on time.** A long-running agent process keeps its detection result for as long as it lives.
- **`AppState` is the only thing SwiftUI reads.** Services return values; they do not publish.
- **The scanner does not block on the inspector.** `inspect` and `context` run inside an actor and serialize naturally; the scanner can keep polling lsof without waiting.
- **No subprocess shells in the hot detection path.** Process metadata comes from `proc_pidinfo` / `sysctl` / `proc_pidpath`. The only shell-outs left in steady-state are `lsof` (the actual port scanner) and `ps` / `lsof -d cwd` (the cheap inspection pass).
- **Force-kill always asks.** `AppState.confirmForceKill` defaults to true and gates both the row context-menu action and the stack-card "Stop all".
- **Filter state is per-session.** Quitting and reopening starts with both filters off. Intentional — the filters are quick affordances, not preferences.

---

## When this document goes stale

Update it when you:

- Add a new service or store in `PortPirateCore`.
- Change the detection pipeline order or the cache invalidation rule.
- Add a new section in `MenuBarPanelView` (or remove one).
- Touch the threading model.

Treat the diagrams as load-bearing. If the actual code does not match them, the diagrams are wrong, not the code.

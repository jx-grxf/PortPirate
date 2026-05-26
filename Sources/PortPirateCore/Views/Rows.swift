import SwiftUI

extension View {
  func panelRowBackground() -> some View {
    glassInteractive()
  }
}

struct SectionHeader: View {
  let title: String
  let systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundStyle(.secondary)
      .symbolRenderingMode(.hierarchical)
  }
}

struct EmptyStateRow: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.callout)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .panelRowBackground()
  }
}

struct StackCardView: View {
  @Bindable var appState: AppState
  let stack: WorkspaceStack
  @State private var isExpanded: Bool = true
  @State private var showingStopConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      DisclosureGroup(isExpanded: $isExpanded.animation(Theme.expand)) {
        VStack(spacing: Theme.s2) {
          ForEach(stack.servers) { server in
            ServerRowView(appState: appState, server: server)
          }
        }
        .padding(.top, Theme.s2)
      } label: {
        header
      }
    }
    .padding(Theme.s3)
    .glassCard()
    .confirmationDialog(
      "Stop \(stack.servers.count) services in \(stack.name)?",
      isPresented: $showingStopConfirmation,
      titleVisibility: .visible
    ) {
      Button("Stop all", role: .destructive) {
        Task { await appState.stopStack(stack) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(stack.servers.map { ":\($0.port)" }.joined(separator: ", "))
    }
  }

  private var header: some View {
    HStack(spacing: Theme.s2) {
      StatusDot(stack.status)
      VStack(alignment: .leading, spacing: 1) {
        Text(stack.name)
          .font(.callout)
          .bold()
          .lineLimit(1)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: Theme.s2)
      if stack.hasMixedBranches {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.yellow)
          .font(.caption)
          .help("Services in this stack are on different git branches")
      }
      Button("Stop all", systemImage: "stop.circle") {
        if appState.confirmForceKill {
          showingStopConfirmation = true
        } else {
          Task { await appState.stopStack(stack) }
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Stop all services in \(stack.name)")
    }
    .contentShape(.rect)
  }

  private var subtitle: String {
    var parts = ["\(stack.servers.count) services"]
    if let branch = stack.branch {
      parts.append(branch)
    } else if stack.hasMixedBranches {
      parts.append("mixed branches")
    }
    if stack.isWorktree {
      parts.append("worktree")
    }
    return parts.joined(separator: " · ")
  }
}

struct ServerRowView: View {
  @Bindable var appState: AppState
  let server: ListeningServer
  var allowsStop = true
  @State private var showingForceKill = false

  var body: some View {
    HStack(spacing: 10) {
      StatusDot(server.warning == nil ? .ok : .warning)

      Image(systemName: server.runtime.systemImage)
        .foregroundStyle(.secondary)
        .symbolRenderingMode(.hierarchical)
        .font(.system(size: 17, weight: .medium))
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(server.displayTitle)
            .font(.callout)
            .bold()
            .lineLimit(1)
          Text(":\(server.displayPort)")
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
          if let owner = OwnerPresentation(server: server) {
            OwnerBadge(owner: owner)
          }
        }
        Text(secondaryLine)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button("Open localhost:\(server.displayPort)", systemImage: "safari") {
        appState.open(server: server)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Open localhost:\(server.displayPort)")

      Button("Diagnose", systemImage: "stethoscope") {
        appState.diagnose(server: server)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Diagnose")

      if allowsStop {
        Button("Stop gracefully", systemImage: "stop.circle") {
          Task { await appState.stop(server: server, force: false) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Stop gracefully")
      }
    }
    .padding(10)
    .panelRowBackground()
    .contextMenu {
      Button("Diagnose") { appState.diagnose(server: server) }
      Button("Open URL") { appState.open(server: server) }
      if allowsStop {
        Button("Force Kill", role: .destructive) { requestForceKill() }
      }
    }
    .confirmationDialog(
      "Force kill PID \(server.processID)?",
      isPresented: $showingForceKill,
      titleVisibility: .visible
    ) {
      Button("Force Kill", role: .destructive) {
        Task { await appState.stop(server: server, force: true) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(server.commandLine)
    }
  }

  private func requestForceKill() {
    if appState.confirmForceKill {
      showingForceKill = true
    } else {
      Task { await appState.stop(server: server, force: true) }
    }
  }

  private var secondaryLine: String {
    var parts: [String] = []
    if let git = server.process?.gitContext {
      var label = git.repoRoot.lastPathComponent
      if let branch = git.branch, !branch.isEmpty {
        label += " · \(branch)"
      }
      if git.isWorktree {
        label += " · worktree"
      }
      parts.append(label)
    } else {
      parts.append(server.workspaceName)
    }
    if let age = RelativeAge.short(from: server.process?.startedAt) {
      parts.append(age)
    }
    return parts.joined(separator: "  ·  ")
  }
}

struct OwnerPresentation: Equatable {
  let label: String
  let tooltip: String
  let tint: Color
  let source: DetectionSource

  init?(server: ListeningServer) {
    guard let owner = server.process?.owner,
          case .aiAgent(let kind, let sessionID, let source) = owner else {
      return nil
    }
    self.label = kind.displayName
    self.tint = kind.tint
    self.source = source
    var tooltipParts: [String] = ["\(kind.displayName) · matched via \(source.tooltipPhrase)"]
    if let sessionID, !sessionID.isEmpty {
      tooltipParts.append("session \(sessionID)")
    }
    if let cwd = server.process?.currentDirectory {
      tooltipParts.append(cwd)
    }
    self.tooltip = tooltipParts.joined(separator: " · ")
  }
}

struct OwnerBadge: View {
  let owner: OwnerPresentation

  var body: some View {
    HStack(spacing: 3) {
      if owner.source == .argv {
        Text("~").font(.caption2.weight(.bold)).foregroundStyle(owner.tint.opacity(0.8))
      }
      Text(owner.label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(owner.tint)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 1)
    .background(fillStyle, in: Capsule())
    .overlay(Capsule().stroke(owner.tint.opacity(strokeOpacity), style: strokeStyle))
    .help(owner.tooltip)
  }

  private var fillStyle: AnyShapeStyle {
    switch owner.source {
    case .env: return AnyShapeStyle(owner.tint.opacity(0.22))
    case .parentChain: return AnyShapeStyle(owner.tint.opacity(0.08))
    case .argv: return AnyShapeStyle(Color.clear)
    }
  }

  private var strokeOpacity: Double {
    switch owner.source {
    case .env: return 0.35
    case .parentChain: return 0.5
    case .argv: return 0.6
    }
  }

  private var strokeStyle: StrokeStyle {
    switch owner.source {
    case .env: return StrokeStyle(lineWidth: 0.5)
    case .parentChain: return StrokeStyle(lineWidth: 0.7)
    case .argv: return StrokeStyle(lineWidth: 0.7, dash: [2, 2])
    }
  }
}

extension DetectionSource {
  var tooltipPhrase: String {
    switch self {
    case .env: return "agent env var (high confidence)"
    case .parentChain: return "parent process chain"
    case .argv: return "argv basename (likely)"
    }
  }
}

extension AgentKind {
  var displayName: String {
    switch self {
    case .claudeCode: return "Claude"
    case .cursor: return "Cursor"
    case .codex: return "Codex"
    case .windsurf: return "Windsurf"
    case .aider: return "Aider"
    case .opencode: return "opencode"
    case .gemini: return "Gemini"
    case .copilot: return "Copilot"
    case .augment: return "Augment"
    case .qwenCode: return "Qwen"
    case .other: return "Agent"
    }
  }

  var tint: Color {
    switch self {
    case .claudeCode: return .orange
    case .cursor: return .purple
    case .codex: return .green
    case .windsurf: return .teal
    case .aider: return .brown
    case .opencode: return .indigo
    case .gemini: return .pink
    case .copilot: return .mint
    case .augment: return .yellow
    case .qwenCode: return .red
    case .other: return .gray
    }
  }
}

enum RelativeAge {
  static func short(from date: Date?, now: Date = Date()) -> String? {
    guard let date else { return nil }
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "\(seconds)s" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    return "\(days)d"
  }
}

struct ProfileRowView: View {
  @Bindable var appState: AppState
  let profile: WorkspaceProfile

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(profile.name)
            .font(.callout)
            .bold()
          Text("\(profile.packageManager.label) • \(URL(fileURLWithPath: profile.path).lastPathComponent)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }

      if profile.scripts.isEmpty {
        Text("No package scripts")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(profile.scripts.prefix(3)) { script in
              Button(script.name) {
                appState.startScript(script, in: profile)
              }
              .controlSize(.small)
              .lineLimit(1)
              .help(script.command)
            }
          }
        }
      }
    }
    .padding(10)
    .panelRowBackground()
  }
}

struct LaunchAgentRow: View {
  let agent: LaunchAgentInfo

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "gearshape.2")
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        Text(agent.label)
          .font(.caption)
          .lineLimit(1)
        Text(agent.state ?? agent.path ?? "read-only")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
    }
    .padding(8)
    .panelRowBackground()
  }
}

struct RunningScriptRow: View {
  @Bindable var appState: AppState
  let script: RunningScript

  var body: some View {
    HStack(spacing: 8) {
      StatusDot(script.isRunning ? .ok : .idle)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(script.profileName): \(script.scriptName)")
          .font(.caption)
          .lineLimit(1)
        Text("PID \(script.processID) • \(script.lines.last ?? "waiting for output")")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if script.isRunning {
        Button("Stop \(script.scriptName)", systemImage: "stop.circle") {
          appState.stopRunningScript(script)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Stop \(script.scriptName)")
      } else {
        Text("Exited")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(8)
    .panelRowBackground()
  }
}

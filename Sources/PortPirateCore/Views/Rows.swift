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
        }
        Text(server.workspaceName)
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
          Text("\(profile.packageManager.rawValue) • \(URL(fileURLWithPath: profile.path).lastPathComponent)")
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

import SwiftUI

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
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct ServerRowView: View {
  @Bindable var appState: AppState
  let server: ListeningServer
  @State private var showingForceKill = false

  var body: some View {
    HStack(spacing: 10) {
      StatusDot(server.warning == nil ? .ok : .warning)

      Image(systemName: server.runtime.systemImage)
        .foregroundStyle(.secondary)
        .symbolRenderingMode(.hierarchical)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(server.runtime.title)
            .font(.callout)
            .fontWeight(.medium)
          Text(":\(server.port)")
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        Text(server.workspaceName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button {
        appState.open(server: server)
      } label: {
        Image(systemName: "safari")
      }
      .buttonStyle(.borderless)
      .help("Open localhost:\(server.port)")

      Button {
        appState.diagnose(server: server)
      } label: {
        Image(systemName: "stethoscope")
      }
      .buttonStyle(.borderless)
      .help("Diagnose")

      Button {
        Task { await appState.stop(server: server, force: false) }
      } label: {
        Image(systemName: "stop.circle")
      }
      .buttonStyle(.borderless)
      .help("Stop gracefully")
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    .contextMenu {
      Button("Diagnose") { appState.diagnose(server: server) }
      Button("Open URL") { appState.open(server: server) }
      Button("Force Kill", role: .destructive) { showingForceKill = true }
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
            .fontWeight(.medium)
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
        HStack {
          ForEach(profile.scripts.prefix(3)) { script in
            Button(script.name) {
              appState.startScript(script, in: profile)
            }
            .controlSize(.small)
          }
        }
      }
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct RunningScriptRow: View {
  @Bindable var appState: AppState
  let script: RunningScript

  var body: some View {
    HStack(spacing: 8) {
      StatusDot(.ok)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(script.profileName): \(script.scriptName)")
          .font(.caption)
          .lineLimit(1)
        Text("PID \(script.processID) • \(script.lines.last ?? "waiting for output")")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Button {
        appState.stopRunningScript(script)
      } label: {
        Image(systemName: "stop.circle")
      }
      .buttonStyle(.borderless)
    }
    .padding(8)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

import SwiftUI

public struct MenuBarPanelView: View {
  @Bindable private var appState: AppState
  @Environment(\.openWindow) private var openWindow

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      diagnosisBar
      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          serverSection
          profileSection
          launchdSection
          logsSection
        }
        .padding(14)
      }

      Divider()
      footer
    }
    .frame(width: 440, height: 560)
    .background(.regularMaterial)
    .task {
      appState.startAutoRefresh()
      await appState.loadProfiles()
      await appState.refresh()
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      StatusDot(appState.status)
      VStack(alignment: .leading, spacing: 2) {
        Text("MacDev")
          .font(.headline)
        Text(summaryText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if appState.isRefreshing {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        Task { await appState.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.borderless)
      .help("Refresh")
    }
    .padding(14)
  }

  private var diagnosisBar: some View {
    HStack(spacing: 8) {
      TextField("Why is port 3000 busy?", text: $appState.diagnosisPortText)
        .textFieldStyle(.roundedBorder)
        .onSubmit { appState.diagnosePortText() }

      Button {
        appState.diagnosePortText()
      } label: {
        Image(systemName: "magnifyingglass")
      }
      .help("Diagnose Port")
    }
    .padding(14)
  }

  private var serverSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "Local runtimes", systemImage: "server.rack")

      if appState.servers.isEmpty {
        EmptyStateRow(title: "No listening dev ports", subtitle: "Start a server and MacDev will pick it up.")
      } else {
        ForEach(appState.servers.prefix(8)) { server in
          ServerRowView(appState: appState, server: server)
        }
      }

      if let diagnostic = appState.diagnosticResult {
        DiagnosticCard(result: diagnostic)
      }
    }
  }

  private var profileSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "Workspaces", systemImage: "folder")

      if appState.profiles.isEmpty {
        EmptyStateRow(title: "No workspace profiles", subtitle: "Add folders in Settings to run package scripts.")
      } else {
        ForEach(appState.profiles.prefix(4)) { profile in
          ProfileRowView(appState: appState, profile: profile)
        }
      }
    }
  }

  private var launchdSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "User agents", systemImage: "gearshape.2")

      if !appState.includeLaunchAgents {
        EmptyStateRow(title: "launchd hidden", subtitle: "Enable read-only user agents in Settings.")
      } else if appState.launchAgents.isEmpty {
        EmptyStateRow(title: "No parsed user agents", subtitle: "MacDev could not parse launchctl entries yet.")
      } else {
        ForEach(appState.launchAgents.prefix(5)) { agent in
          LaunchAgentRow(agent: agent)
        }
      }
    }
  }

  private var logsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "Started by MacDev", systemImage: "doc.text.magnifyingglass")

      if appState.runningScripts.isEmpty {
        EmptyStateRow(title: "No managed logs", subtitle: "Logs appear for scripts launched by MacDev.")
      } else {
        ForEach(appState.runningScripts) { script in
          RunningScriptRow(appState: appState, script: script)
        }
      }
    }
  }

  private var footer: some View {
    HStack {
      SettingsLink {
        Label("Settings", systemImage: "gearshape")
      }

      Button {
        openWindow(id: "runtime-browser")
      } label: {
        Label("Runtime Browser", systemImage: "sidebar.leading")
      }

      Spacer()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    }
    .padding(12)
  }

  private var summaryText: String {
    let count = appState.servers.count
    let warnings = appState.warningCount
    if count == 0 { return "No local runtimes detected" }
    if warnings == 0 { return "\(count) active, no warnings" }
    return "\(count) active, \(warnings) warning\(warnings == 1 ? "" : "s")"
  }
}

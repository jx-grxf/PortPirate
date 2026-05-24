import SwiftUI

public struct MenuBarPanelView: View {
  @Bindable private var appState: AppState
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings
  @State private var isAppleServicesExpanded = false
  @State private var isBackgroundExpanded = false
  @State private var isToolsExpanded = false

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    VStack(spacing: 0) {
      header
      diagnosisBar

      ScrollView {
        VStack(alignment: .leading, spacing: Theme.s3) {
          if let errorMessage = appState.errorMessage {
            ErrorBanner(message: errorMessage) {
              Task { await appState.refresh() }
            }
          }
          serverSection
          backgroundSection
          appleServicesSection
          toolsSection
        }
        .padding(Theme.s3)
      }
      .scrollContentBackground(.hidden)

      footer
    }
    .frame(width: 440, height: 560)
    .background(.ultraThinMaterial)
    .task {
      await appState.bootstrap()
      await appState.refreshNotificationAuthorization()
    }
  }

  private var header: some View {
    HStack(spacing: Theme.s3) {
      StatusDot(appState.status)
      VStack(alignment: .leading, spacing: 1) {
        Text("PortPirate")
          .font(.headline)
        Text(summaryText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if appState.isRefreshing {
        ProgressView()
          .controlSize(.small)
      }
      Button("Refresh", systemImage: "arrow.clockwise") {
        Task { await appState.refresh() }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Refresh")
      .disabled(appState.isRefreshing)
    }
    .padding(.horizontal, Theme.s4)
    .padding(.vertical, Theme.s3)
  }

  private var diagnosisBar: some View {
    HStack(spacing: Theme.s2) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)

      TextField("Diagnose a port…", text: $appState.diagnosisPortText)
        .textFieldStyle(.plain)
        .onSubmit { appState.diagnosePortText() }
        .accessibilityLabel("Port to diagnose")

      if !appState.diagnosisPortText.isEmpty {
        Button {
          appState.diagnosePortText()
        } label: {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Diagnose Port")
      }
    }
    .padding(.horizontal, Theme.s3)
    .padding(.vertical, Theme.s2 + 1)
    .glassInteractive(cornerRadius: 10)
    .padding(.horizontal, Theme.s3)
    .padding(.bottom, Theme.s2)
  }

  private var serverSection: some View {
    VStack(alignment: .leading, spacing: Theme.s2) {
      SectionHeader(title: "Local runtimes", systemImage: "server.rack")

      if appState.developerServers.isEmpty {
        EmptyStateRow(title: "No listening dev ports", subtitle: "Start a server and PortPirate will pick it up.")
      } else {
        ForEach(appState.developerServers.prefix(8)) { server in
          ServerRowView(appState: appState, server: server)
        }
      }

      if let diagnostic = appState.diagnosticResult {
        DiagnosticCard(result: diagnostic)
      }
    }
  }

  @ViewBuilder
  private var backgroundSection: some View {
    let backgroundServers = appState.backgroundServers

    if !backgroundServers.isEmpty {
      DisclosureGroup(isExpanded: $isBackgroundExpanded.animation(Theme.expand)) {
        VStack(spacing: Theme.s2) {
          ForEach(backgroundServers.prefix(6)) { server in
            ServerRowView(appState: appState, server: server, allowsStop: false)
          }
        }
        .padding(.top, Theme.s2)
      } label: {
        sectionLabel("Other listeners", systemImage: "app.connected.to.app.below.fill", count: backgroundServers.count)
      }
    }
  }

  @ViewBuilder
  private var appleServicesSection: some View {
    let appleServices = appState.appleServiceServers

    if !appleServices.isEmpty {
      DisclosureGroup(isExpanded: $isAppleServicesExpanded.animation(Theme.expand)) {
        VStack(spacing: Theme.s2) {
          if appState.showAppleServices {
            ForEach(appleServices.prefix(8)) { server in
              ServerRowView(appState: appState, server: server, allowsStop: false)
            }
          } else {
            EmptyStateRow(
              title: "Apple services hidden",
              subtitle: "Enable them in Settings if you want system listeners in the menu."
            )
          }
        }
        .padding(.top, Theme.s2)
      } label: {
        sectionLabel("Apple services", systemImage: "apple.logo", count: appleServices.count)
      }
    }
  }

  private var toolsSection: some View {
    DisclosureGroup(isExpanded: $isToolsExpanded.animation(Theme.expand)) {
      VStack(alignment: .leading, spacing: Theme.s3) {
        profileSection
        launchdSection
        logsSection
      }
      .padding(.top, Theme.s2)
    } label: {
      sectionLabel("Tools", systemImage: "wrench.and.screwdriver")
    }
  }

  private func sectionLabel(_ title: String, systemImage: String, count: Int? = nil) -> some View {
    HStack(spacing: Theme.s2) {
      SectionHeader(title: title, systemImage: systemImage)
      Spacer()
      if let count {
        Text("\(count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .padding(.horizontal, 7)
          .padding(.vertical, 1)
          .background(.quaternary, in: Capsule())
      }
    }
    .contentShape(.rect)
  }

  private var profileSection: some View {
    VStack(alignment: .leading, spacing: Theme.s2) {
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
    VStack(alignment: .leading, spacing: Theme.s2) {
      SectionHeader(title: "User agents", systemImage: "gearshape.2")

      if !appState.includeLaunchAgents {
        EmptyStateRow(title: "launchd hidden", subtitle: "Enable read-only user agents in Settings.")
      } else if appState.launchAgents.isEmpty {
        EmptyStateRow(title: "No parsed user agents", subtitle: "PortPirate could not parse launchctl entries yet.")
      } else {
        ForEach(appState.launchAgents.prefix(5)) { agent in
          LaunchAgentRow(agent: agent)
        }
      }
    }
  }

  private var logsSection: some View {
    VStack(alignment: .leading, spacing: Theme.s2) {
      SectionHeader(title: "Started by PortPirate", systemImage: "doc.text.magnifyingglass")

      if appState.runningScripts.isEmpty {
        EmptyStateRow(title: "No managed logs", subtitle: "Logs appear for scripts launched by PortPirate.")
      } else {
        ForEach(appState.runningScripts) { script in
          RunningScriptRow(appState: appState, script: script)
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: Theme.s2) {
      Button {
        PortPirateWindowFocus.activateApp()
        openSettings()
        PortPirateWindowFocus.bringSettingsForward()
      } label: {
        Label("Settings", systemImage: "gearshape")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Settings")

      Button {
        PortPirateWindowFocus.activateApp()
        openWindow(id: "runtime-browser")
        PortPirateWindowFocus.bringWindowForward(title: "Runtime Browser")
      } label: {
        Label("Runtime Browser", systemImage: "sidebar.leading")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Runtime Browser")

      Spacer()

      Button {
        NSApplication.shared.terminate(nil)
      } label: {
        Label("Quit", systemImage: "power")
      }
      .labelStyle(.iconOnly)
      .keyboardShortcut("q")
      .buttonStyle(.borderless)
      .help("Quit PortPirate")
    }
    .controlSize(.small)
    .padding(.horizontal, Theme.s4)
    .padding(.vertical, Theme.s3 - 2)
  }

  private var summaryText: String {
    if let errorMessage = appState.errorMessage {
      return errorMessage
    }
    let count = appState.developerServers.count
    let backgroundCount = appState.backgroundServers.count
    let warnings = appState.warningCount
    let listenerText = backgroundCount == 0 ? "" : ", \(backgroundCount) other"
    if count == 0 { return "No dev runtimes\(listenerText)" }
    if warnings == 0 { return "\(count) active\(listenerText)" }
    return "\(count) active, \(warnings) warning\(warnings == 1 ? "" : "s")\(listenerText)"
  }
}

private struct ErrorBanner: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    HStack(spacing: Theme.s2) {
      Label(message, systemImage: "exclamationmark.triangle")
        .lineLimit(2)
      Spacer(minLength: Theme.s2)
      Button("Retry", systemImage: "arrow.clockwise", action: retry)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Retry scan")
    }
    .font(.caption)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.s3)
    .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.rowRadius))
  }
}

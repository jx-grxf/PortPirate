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
      Divider()
      diagnosisBar
      Divider()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
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
        .padding(14)
      }

      Divider()
      footer
    }
    .frame(width: 440, height: 560)
    .background(.regularMaterial)
    .task {
      await appState.bootstrap()
      await appState.refreshNotificationAuthorization()
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
    .padding(14)
  }

  private var diagnosisBar: some View {
    HStack(spacing: 8) {
      TextField("3000", text: $appState.diagnosisPortText)
        .textFieldStyle(.roundedBorder)
        .onSubmit { appState.diagnosePortText() }
        .accessibilityLabel("Port to diagnose")

      Button("Diagnose Port", systemImage: "magnifyingglass") {
        appState.diagnosePortText()
      }
      .labelStyle(.iconOnly)
      .help("Diagnose Port")
    }
    .padding(14)
  }

  private var serverSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "Local runtimes", systemImage: "server.rack")

      if appState.developerServers.isEmpty {
        EmptyStateRow(title: "No listening dev ports", subtitle: "Start a server and MacDev will pick it up.")
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
      VStack(alignment: .leading, spacing: 8) {
        Button {
          withAnimation(.snappy(duration: 0.18)) {
            isBackgroundExpanded.toggle()
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: isBackgroundExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: 12)
            SectionHeader(title: "Other listeners", systemImage: "app.connected.to.app.below.fill")
            Spacer()
            Text("\(backgroundServers.count)")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Other listeners")
        .accessibilityValue(isBackgroundExpanded ? "Expanded" : "Collapsed")

        if isBackgroundExpanded {
          ForEach(backgroundServers.prefix(6)) { server in
            ServerRowView(appState: appState, server: server, allowsStop: false)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var appleServicesSection: some View {
    let appleServices = appState.appleServiceServers

    if !appleServices.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Button {
          withAnimation(.snappy(duration: 0.18)) {
            isAppleServicesExpanded.toggle()
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: isAppleServicesExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: 12)
            SectionHeader(title: "Apple services", systemImage: "apple.logo")
            Spacer()
            Text("\(appleServices.count)")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple services")
        .accessibilityValue(isAppleServicesExpanded ? "Expanded" : "Collapsed")

        if appState.showAppleServices {
          if isAppleServicesExpanded {
            ForEach(appleServices.prefix(8)) { server in
              ServerRowView(appState: appState, server: server, allowsStop: false)
            }
          }
        } else {
          EmptyStateRow(
            title: "Apple services hidden",
            subtitle: "Enable them in Settings if you want system listeners in the menu."
          )
        }
      }
    }
  }

  private var toolsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(.snappy(duration: 0.18)) {
          isToolsExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: isToolsExpanded ? "chevron.down" : "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 12)
          SectionHeader(title: "Tools", systemImage: "wrench.and.screwdriver")
          Spacer()
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Tools")
      .accessibilityValue(isToolsExpanded ? "Expanded" : "Collapsed")

      if isToolsExpanded {
        profileSection
        launchdSection
        logsSection
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
    HStack(spacing: 10) {
      Button {
        MacDevWindowFocus.activateApp()
        openSettings()
        MacDevWindowFocus.bringSettingsForward()
      } label: {
        Label("Settings", systemImage: "gearshape")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help("Settings")

      Button {
        MacDevWindowFocus.activateApp()
        openWindow(id: "runtime-browser")
        MacDevWindowFocus.bringWindowForward(title: "Runtime Browser")
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
      .help("Quit MacDev")
    }
    .controlSize(.small)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
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
    HStack(spacing: 8) {
      Label(message, systemImage: "exclamationmark.triangle")
        .lineLimit(2)
      Spacer(minLength: 8)
      Button("Retry", systemImage: "arrow.clockwise", action: retry)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Retry scan")
    }
    .font(.caption)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
  }
}

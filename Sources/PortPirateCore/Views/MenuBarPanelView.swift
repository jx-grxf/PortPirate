import SwiftUI

public struct MenuBarPanelView: View {
  @Bindable private var appState: AppState
  @Environment(\.openWindow) private var openWindow
  @Environment(\.openSettings) private var openSettings
  @State private var isAppleServicesExpanded = false
  @State private var isBackgroundExpanded = false
  @State private var isEditorHelpersExpanded = false
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
          editorHelpersSection
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

      if appState.developerServers.isEmpty && appState.manualWorkspaceRuntimeScripts.isEmpty {
        EmptyStateRow(title: emptyStateTitle, subtitle: emptyStateSubtitle)
      } else {
        if !appState.developerServers.isEmpty {
          filterChips
          let grouped = appState.groupedDeveloperServers
          if grouped.stacks.isEmpty && grouped.ungrouped.isEmpty {
            EmptyStateRow(
              title: "No matches for current filter",
              subtitle: filterEmptySubtitle
            )
          } else {
            let rowCap = 8
            ForEach(grouped.stacks) { stack in
              StackCardView(appState: appState, stack: stack)
            }
            ForEach(grouped.ungrouped.prefix(rowCap)) { server in
              ServerRowView(appState: appState, server: server)
            }
            if grouped.ungrouped.count > rowCap {
              MoreRow(count: grouped.ungrouped.count - rowCap, total: grouped.ungrouped.count)
            }
          }
        }

        if !appState.manualWorkspaceRuntimeScripts.isEmpty {
          VStack(alignment: .leading, spacing: Theme.s2) {
            if !appState.developerServers.isEmpty {
              SectionHeader(title: "Workspace scripts", systemImage: "terminal")
            }
            ForEach(appState.manualWorkspaceRuntimeScripts) { script in
              RunningScriptRow(appState: appState, script: script)
            }
          }
        }
      }

      if let diagnostic = appState.diagnosticResult {
        DiagnosticCard(result: diagnostic)
      }
    }
  }

  private var emptyStateTitle: String {
    if appState.backgroundServers.isEmpty && appState.editorHelperServers.isEmpty {
      return "No listening dev ports"
    }
    return "No primary dev runtimes"
  }

  private var emptyStateSubtitle: String {
    let other = appState.backgroundServers.count + appState.editorHelperServers.count
    if other == 0 {
      return "Start a server and PortPirate will pick it up."
    }
    return "Listeners are hiding in the disclosures below: \(other) total."
  }

  private var filterEmptySubtitle: String {
    var parts: [String] = []
    if appState.filterAIAgentsOnly { parts.append("AI coding agents") }
    if appState.filterAssistantsOnly { parts.append("always-on assistants") }
    if appState.filterStaleOnly { parts.append("processes older than 30 minutes") }
    if parts.isEmpty { return "No matching processes." }
    return "No " + parts.joined(separator: " + ") + " right now."
  }

  @ViewBuilder
  private var filterChips: some View {
    let showAgent = appState.hasAgentDetectedServers || appState.filterAIAgentsOnly
    let showAssistant = appState.hasAssistantServers || appState.filterAssistantsOnly
    let showStale = appState.hasStaleServers || appState.filterStaleOnly
    if showAgent || showAssistant || showStale {
      HStack(spacing: Theme.s2) {
        if showAgent {
          FilterChip(
            label: "AI agents",
            systemImage: "sparkles",
            isOn: $appState.filterAIAgentsOnly
          )
        }
        if showAssistant {
          FilterChip(
            label: "Always-on",
            systemImage: "infinity",
            isOn: $appState.filterAssistantsOnly
          )
        }
        if showStale {
          FilterChip(
            label: "Stale >30m",
            systemImage: "clock.badge.exclamationmark",
            isOn: $appState.filterStaleOnly
          )
        }
        Spacer()
      }
    }
  }

  @ViewBuilder
  private var backgroundSection: some View {
    let backgroundServers = appState.backgroundServers

    if !backgroundServers.isEmpty {
      DisclosureGroup(isExpanded: $isBackgroundExpanded.animation(Theme.expand)) {
        VStack(spacing: Theme.s2) {
          ForEach(backgroundServers.prefix(40)) { server in
            ServerRowView(appState: appState, server: server, allowsStop: false)
          }
          if backgroundServers.count > 40 {
            MoreRow(count: backgroundServers.count - 40, total: backgroundServers.count)
          }
        }
        .padding(.top, Theme.s2)
      } label: {
        sectionLabel("Other listeners", systemImage: "app.connected.to.app.below.fill", count: backgroundServers.count)
      }
    }
  }

  @ViewBuilder
  private var editorHelpersSection: some View {
    let helpers = appState.editorHelperServers

    if !helpers.isEmpty {
      DisclosureGroup(isExpanded: $isEditorHelpersExpanded.animation(Theme.expand)) {
        VStack(spacing: Theme.s2) {
          ForEach(helpers.prefix(40)) { server in
            ServerRowView(appState: appState, server: server, allowsStop: false)
          }
          if helpers.count > 40 {
            MoreRow(count: helpers.count - 40, total: helpers.count)
          }
        }
        .padding(.top, Theme.s2)
      } label: {
        sectionLabel("Editor helpers", systemImage: "chevron.left.forwardslash.chevron.right", count: helpers.count)
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
            ForEach(appleServices.prefix(40)) { server in
              ServerRowView(appState: appState, server: server, allowsStop: false)
            }
            if appleServices.count > 40 {
              MoreRow(count: appleServices.count - 40, total: appleServices.count)
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

      if appState.visibleManagedScripts.isEmpty {
        EmptyStateRow(title: "No managed logs", subtitle: "Logs appear for scripts launched by PortPirate.")
      } else {
        ForEach(appState.visibleManagedScripts) { script in
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
    let count = appState.developerServers.count + appState.manualWorkspaceRuntimeScripts.count + appState.visibleManagedScripts.filter(\.isRunning).count
    let otherCount = appState.backgroundServers.count + appState.editorHelperServers.count
    let warnings = appState.warningCount
    let listenerText = otherCount == 0 ? "" : ", \(otherCount) other"
    if count == 0 { return "No dev runtimes\(listenerText)" }
    if warnings == 0 { return "\(count) active\(listenerText)" }
    return "\(count) active, \(warnings) warning\(warnings == 1 ? "" : "s")\(listenerText)"
  }
}

struct FilterChip: View {
  let label: String
  let systemImage: String
  @Binding var isOn: Bool

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: systemImage)
        Text(label)
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(isOn ? Color.accentColor : .secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(
        Capsule().fill(isOn ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04))
      )
      .overlay(
        Capsule().strokeBorder(
          isOn ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08),
          lineWidth: 0.5
        )
      )
    }
    .buttonStyle(.plain)
    .help(isOn ? "Showing only \(label)" : "Filter: \(label)")
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

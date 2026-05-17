import AppKit
import SwiftUI

public struct SettingsView: View {
  @Bindable private var appState: AppState
  @SceneStorage("settings.selectedPane") private var selectedPaneRaw = SettingsPane.general.rawValue

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    VStack(spacing: 0) {
      settingsToolbar
      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text(selectedPane.title)
            .font(.title)
            .bold()

          selectedPaneContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 46)
        .padding(.vertical, 32)
      }
      .scrollContentBackground(.visible)
    }
    .frame(width: 760, height: 560)
    .background(.regularMaterial)
    .task {
      await appState.loadProfiles()
      await appState.refreshNotificationAuthorization()
    }
  }

  private var selectedPane: SettingsPane {
    SettingsPane(rawValue: selectedPaneRaw) ?? .general
  }

  private var settingsToolbar: some View {
    HStack(spacing: 14) {
      ForEach(SettingsPane.allCases) { pane in
        Button {
          selectedPaneRaw = pane.rawValue
        } label: {
          VStack(spacing: 6) {
            Image(systemName: pane.systemImage)
              .font(.title2)
              .symbolRenderingMode(.hierarchical)
            Text(pane.title)
              .font(.caption)
          }
          .frame(width: 78, height: 62)
          .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedPane == pane ? Color.accentColor : Color.secondary)
        .background(
          selectedPane == pane ? Color.accentColor.opacity(0.14) : Color.clear,
          in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityLabel(pane.title)
      }
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  private var selectedPaneContent: some View {
    switch selectedPane {
    case .general:
      generalTab
    case .discovery:
      discoveryTab
    case .actions:
      actionsTab
    case .notifications:
      notificationsTab
    case .updates:
      updatesTab
    case .about:
      aboutTab
    }
  }

  private var generalTab: some View {
    SettingsSection("Menu bar") {
      Toggle("Show runtime count", isOn: $appState.showStatusCount)

      LabeledContent("Refresh interval") {
        HStack(spacing: 12) {
          Slider(value: $appState.refreshInterval, in: 2...30, step: 1)
            .frame(width: 260)
          Text("\(Int(appState.refreshInterval))s")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 36, alignment: .trailing)
        }
      }
    }
  }

  private var discoveryTab: some View {
    VStack(alignment: .leading, spacing: 16) {
      SettingsSection("System visibility") {
        Toggle("Show Apple services in menu bar", isOn: $appState.showAppleServices)
        Toggle("Show launchd user agents read-only", isOn: $appState.includeLaunchAgents)
        Text("Apple services are separated from local dev runtimes so system ports like AirPlay do not look like project servers.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack {
        Text("Workspace profiles")
          .font(.headline)
        Spacer()
        Button {
          chooseWorkspace()
        } label: {
          Label("Add Folder", systemImage: "plus")
        }
      }

      if appState.profiles.isEmpty {
        ContentUnavailableView(
          "No Workspace Profiles",
          systemImage: "folder.badge.plus",
          description: Text("Add a project folder that contains package.json.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
      } else {
        VStack(spacing: 8) {
          ForEach(appState.profiles) { profile in
            WorkspaceProfileSettingsRow(profile: profile) {
              appState.removeProfile(profile)
            }
          }
        }
      }
    }
  }

  private var actionsTab: some View {
    SettingsSection("Process control") {
      Toggle("Confirm before force killing a process", isOn: $appState.confirmForceKill)
      Text("MacDev always sends SIGTERM first from the normal Stop action. Force Kill is reserved for explicit destructive actions.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var notificationsTab: some View {
    VStack(alignment: .leading, spacing: 18) {
      SettingsSection("Permission") {
        LabeledContent("Status", value: appState.notificationAuthorization.title)
        HStack {
          Button {
            Task { await appState.requestNotifications() }
          } label: {
            Label("Enable Notifications", systemImage: "bell.badge")
          }
          Button {
            Task { await appState.sendTestNotification() }
          } label: {
            Label("Send Test", systemImage: "paperplane")
          }
        }
      }

      SettingsSection("Notify me when") {
        Toggle("A port collision or system warning appears", isOn: notificationBinding(\.portCollisionsEnabled))
        Toggle("A MacDev-managed process exits with an error", isOn: notificationBinding(\.managedProcessCrashEnabled))
        Toggle("An expected workspace port is missing", isOn: notificationBinding(\.expectedPortMissingEnabled))
        Toggle("A runtime scan fails", isOn: notificationBinding(\.scanFailureEnabled))
      }
    }
  }

  private var updatesTab: some View {
    SettingsSection("Updates") {
      Toggle("Check for updates automatically", isOn: .constant(true))
      Picker("Update channel", selection: .constant("Stable")) {
        Text("Stable").tag("Stable")
        Text("Beta").tag("Beta")
      }
      .pickerStyle(.menu)
      Button("Check for Updates...", systemImage: "arrow.down.circle") {}
      Text("Sparkle-backed updates are wired in this release branch. Stable receives normal GitHub releases; Beta also receives prereleases.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var aboutTab: some View {
    VStack(alignment: .center, spacing: 16) {
      Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
        .resizable()
        .frame(width: 112, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 24))

      VStack(spacing: 4) {
        Text("MacDev")
          .font(.title2)
          .bold()
        Text("Native macOS menu bar control center for local developer runtimes.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      HStack(spacing: 18) {
        Link("GitHub", destination: URL(string: "https://github.com/jx-grxf/MacDev")!)
        Link("Website", destination: URL(string: "https://johannesgrof.me/projects/macdev")!)
        Link("Releases", destination: URL(string: "https://github.com/jx-grxf/MacDev/releases")!)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func notificationBinding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
    Binding {
      appState.notificationSettings[keyPath: keyPath]
    } set: { value in
      var settings = appState.notificationSettings
      settings[keyPath: keyPath] = value
      appState.notificationSettings = settings
    }
  }

  private func chooseWorkspace() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Add"

    if panel.runModal() == .OK, let url = panel.url {
      appState.addWorkspace(url: url)
    }
  }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
  case general
  case discovery
  case actions
  case notifications
  case updates
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .discovery: "Discovery"
    case .actions: "Actions"
    case .notifications: "Notifications"
    case .updates: "Updates"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .discovery: "dot.radiowaves.left.and.right"
    case .actions: "hand.raised"
    case .notifications: "bell"
    case .updates: "arrow.down.circle"
    case .about: "info.circle"
    }
  }
}

private struct SettingsSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)

      VStack(alignment: .leading, spacing: 12) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct WorkspaceProfileSettingsRow: View {
  let profile: WorkspaceProfile
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "folder")
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(profile.name)
          .font(.callout)
        Text(profile.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Text(profile.packageManager.rawValue)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)

      Button(role: .destructive, action: remove) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .help("Remove profile")
    }
    .padding(10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

import AppKit
import SwiftUI

public struct SettingsView: View {
  @Bindable private var appState: AppState
  @State private var selectedPane: SettingsPane = .general

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    HStack(spacing: 0) {
      settingsSidebar

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text(selectedPane.title)
            .font(.title2)
            .bold()

          selectedPaneContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
      }
      .scrollContentBackground(.visible)
    }
    .frame(width: 680, height: 420)
    .background(.regularMaterial)
    .task {
      await appState.loadProfiles()
    }
  }

  private var settingsSidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("MacDev")
        .font(.headline)
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 8)

      ForEach(SettingsPane.allCases) { pane in
        Button {
          selectedPane = pane
        } label: {
          Label(pane.title, systemImage: pane.systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SettingsSidebarButtonStyle(isSelected: selectedPane == pane))
      }

      Spacer()
    }
    .frame(width: 180)
    .background(.ultraThinMaterial)
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
      Toggle("Show launchd user agents read-only", isOn: $appState.includeLaunchAgents)

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
    SettingsSection("Planned notifications") {
      SettingsRoadmapRow(title: "Port collision notifications", systemImage: "exclamationmark.triangle")
      SettingsRoadmapRow(title: "Managed process crash notifications", systemImage: "waveform.path.ecg")
      SettingsRoadmapRow(title: "Expected port missing notifications", systemImage: "bell.badge")
      Text("Notifications are planned after the local scanner and workspace flow are stable.")
        .font(.caption)
        .foregroundStyle(.secondary)
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

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .discovery: "Discovery"
    case .actions: "Actions"
    case .notifications: "Notifications"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .discovery: "dot.radiowaves.left.and.right"
    case .actions: "hand.raised"
    case .notifications: "bell"
    }
  }
}

private struct SettingsSidebarButtonStyle: ButtonStyle {
  let isSelected: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout)
      .foregroundStyle(isSelected ? .primary : .secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
        }
      }
      .padding(.horizontal, 8)
      .contentShape(.rect)
      .opacity(configuration.isPressed ? 0.75 : 1)
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

private struct SettingsRoadmapRow: View {
  let title: String
  let systemImage: String

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .foregroundStyle(.secondary)
        .frame(width: 18)
      Text(title)
      Spacer()
      Text("Later")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
  }
}

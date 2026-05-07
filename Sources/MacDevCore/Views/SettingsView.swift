import AppKit
import SwiftUI

public struct SettingsView: View {
  @Bindable private var appState: AppState

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    TabView {
      generalTab
        .tabItem { Label("General", systemImage: "gearshape") }

      discoveryTab
        .tabItem { Label("Discovery", systemImage: "dot.radiowaves.left.and.right") }

      actionsTab
        .tabItem { Label("Actions", systemImage: "hand.raised") }

      notificationsTab
        .tabItem { Label("Notifications", systemImage: "bell") }
    }
    .frame(width: 560, height: 380)
    .scenePadding()
    .task {
      await appState.loadProfiles()
    }
  }

  private var generalTab: some View {
    Form {
      Toggle("Show runtime count in menu bar", isOn: $appState.showStatusCount)

      VStack(alignment: .leading) {
        Text("Refresh interval: \(Int(appState.refreshInterval))s")
        Slider(value: $appState.refreshInterval, in: 2...30, step: 1)
      }
    }
    .padding()
  }

  private var discoveryTab: some View {
    VStack(alignment: .leading, spacing: 14) {
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

      List {
        ForEach(appState.profiles) { profile in
          HStack {
            VStack(alignment: .leading) {
              Text(profile.name)
              Text(profile.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Text(profile.packageManager.rawValue)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
            Button(role: .destructive) {
              appState.removeProfile(profile)
            } label: {
              Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
          }
        }
      }
    }
    .padding()
  }

  private var actionsTab: some View {
    Form {
      Toggle("Confirm before force killing a process", isOn: $appState.confirmForceKill)
      Text("MacDev always sends SIGTERM first from the normal Stop action. Force Kill is reserved for explicit destructive actions.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
  }

  private var notificationsTab: some View {
    Form {
      Toggle("Port collision notifications", isOn: .constant(false))
      Toggle("Managed process crash notifications", isOn: .constant(false))
      Toggle("Expected port missing notifications", isOn: .constant(false))
      Text("Notifications are planned after the local scanner and workspace flow are stable.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
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

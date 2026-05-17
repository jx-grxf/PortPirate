import AppKit
import SwiftUI

public struct SettingsView: View {
  @Bindable private var appState: AppState
  @SceneStorage("settings.selectedPane") private var selectedPaneRaw = SettingsPane.general.rawValue

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    TabView(selection: $selectedPaneRaw) {
      generalPane
        .tabItem { Label(SettingsPane.general.title, systemImage: SettingsPane.general.systemImage) }
        .tag(SettingsPane.general.rawValue)

      discoveryPane
        .tabItem { Label(SettingsPane.discovery.title, systemImage: SettingsPane.discovery.systemImage) }
        .tag(SettingsPane.discovery.rawValue)

      actionsPane
        .tabItem { Label(SettingsPane.actions.title, systemImage: SettingsPane.actions.systemImage) }
        .tag(SettingsPane.actions.rawValue)

      notificationsPane
        .tabItem { Label(SettingsPane.notifications.title, systemImage: SettingsPane.notifications.systemImage) }
        .tag(SettingsPane.notifications.rawValue)

      updatesPane
        .tabItem { Label(SettingsPane.updates.title, systemImage: SettingsPane.updates.systemImage) }
        .tag(SettingsPane.updates.rawValue)

      aboutPane
        .tabItem { Label(SettingsPane.about.title, systemImage: SettingsPane.about.systemImage) }
        .tag(SettingsPane.about.rawValue)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
    .frame(width: selectedPane.preferredWidth, height: SettingsPane.windowHeight)
    .task {
      await appState.loadProfiles()
      await appState.refreshNotificationAuthorization()
    }
  }

  private var selectedPane: SettingsPane {
    SettingsPane(rawValue: selectedPaneRaw) ?? .general
  }

  private var generalPane: some View {
    PreferencePane {
      PreferenceSection("MENU BAR") {
        PreferenceToggleRow(
          title: "Show runtime count",
          subtitle: "Display the number of visible runtimes next to the menu bar icon.",
          isOn: $appState.showStatusCount
        )

        PreferenceSliderRow(
          title: "Refresh interval",
          subtitle: "How often MacDev scans localhost listeners in the background.",
          value: $appState.refreshInterval,
          range: 2...30,
          step: 1,
          formattedValue: "\(Int(appState.refreshInterval))s"
        )
      }

      PreferenceDivider()

      PreferenceSection("WINDOWS") {
        PreferenceInfoRow(
          systemImage: "menubar.rectangle",
          title: "Menu bar first",
          subtitle: "MacDev intentionally has no Dock icon. Settings and Runtime Browser open as utility windows."
        )
      }
    }
  }

  private var discoveryPane: some View {
    PreferencePane {
      PreferenceSection("SYSTEM VISIBILITY") {
        PreferenceToggleRow(
          title: "Show Apple services in menu bar",
          subtitle: "Keep AirPlay and other system listeners visible, separated from local runtimes.",
          isOn: $appState.showAppleServices
        )

        PreferenceToggleRow(
          title: "Show launchd user agents",
          subtitle: "Read-only visibility for user agents. MacDev does not stop launchd services.",
          isOn: $appState.includeLaunchAgents
        )
      }

      PreferenceDivider()

      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("WORKSPACE PROFILES")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("Project folders with package.json scripts.")
            .font(.footnote)
            .foregroundStyle(.tertiary)
        }

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
          description: Text("Add a project folder to discover npm, pnpm, yarn, or bun scripts.")
        )
        .frame(maxWidth: .infinity, minHeight: 210)
      } else {
        VStack(spacing: 0) {
          ForEach(appState.profiles) { profile in
            WorkspaceProfileSettingsRow(profile: profile) {
              appState.removeProfile(profile)
            }

            if profile.id != appState.profiles.last?.id {
              Divider()
                .padding(.leading, 34)
            }
          }
        }
      }
    }
  }

  private var actionsPane: some View {
    PreferencePane {
      PreferenceSection("PROCESS CONTROL") {
        PreferenceToggleRow(
          title: "Confirm before force killing a process",
          subtitle: "Normal Stop sends SIGTERM after PID revalidation. Force Kill remains an explicit destructive action.",
          isOn: $appState.confirmForceKill
        )

        PreferenceInfoRow(
          systemImage: "checkmark.shield",
          title: "Stop actions are revalidated",
          subtitle: "MacDev checks PID, port, command, owner, and working directory before touching a process."
        )

        PreferenceInfoRow(
          systemImage: "lock",
          title: "System services are blocked",
          subtitle: "Apple, Docker, Homebrew, and background listeners stay diagnostic-only unless they are primary local runtimes."
        )
      }
    }
  }

  private var notificationsPane: some View {
    PreferencePane {
      PreferenceSection("PERMISSION") {
        PreferenceValueRow(title: "Status", value: appState.notificationAuthorization.title)

        HStack(spacing: 10) {
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

      PreferenceDivider()

      PreferenceSection("NOTIFY ME WHEN") {
        PreferenceToggleRow(
          title: "A port collision or system warning appears",
          subtitle: "Useful when a server moves ports or a system listener owns a common dev port.",
          isOn: notificationBinding(\.portCollisionsEnabled)
        )
        PreferenceToggleRow(
          title: "A MacDev-managed process exits with an error",
          subtitle: "Only applies to scripts launched from MacDev workspace profiles.",
          isOn: notificationBinding(\.managedProcessCrashEnabled)
        )
        PreferenceToggleRow(
          title: "An expected workspace port is missing",
          subtitle: "Warns when a known project port disappears after refresh.",
          isOn: notificationBinding(\.expectedPortMissingEnabled)
        )
        PreferenceToggleRow(
          title: "A runtime scan fails",
          subtitle: "Surfaces failures from lsof, ps, launchctl, or profile discovery.",
          isOn: notificationBinding(\.scanFailureEnabled)
        )
      }
    }
  }

  private var updatesPane: some View {
    PreferencePane {
      PreferenceSection("SPARKLE UPDATES") {
        PreferenceToggleRow(
          title: "Check for updates automatically",
          subtitle: "Uses the signed GitHub Releases appcast when this build includes a Sparkle public key.",
          isOn: $appState.automaticallyChecksForUpdates
        )

        PreferencePickerRow(title: "Update channel", subtitle: updateChannelDescription) {
          Picker("Update channel", selection: $appState.updateChannel) {
            ForEach(UpdateChannel.allCases) { channel in
              Text(channel.title).tag(channel)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 150)
        }

        HStack {
          Button("Check for Updates...", systemImage: "arrow.down.circle") {
            appState.checkForUpdates()
          }
          .disabled(!appState.updatesConfigured)

          Spacer()
        }

        if appState.updatesConfigured {
          PreferenceInfoRow(
            systemImage: "checkmark.seal",
            title: "Update feed configured",
            subtitle: "Stable receives normal GitHub releases. Beta receives prereleases in addition to stable releases."
          )
        } else {
          PreferenceInfoRow(
            systemImage: "exclamationmark.triangle",
            title: "Local build update checks are disabled",
            subtitle: "Package with MACDEV_SPARKLE_PUBLIC_KEY to enable Sparkle in this app bundle."
          )
        }
      }
    }
  }

  private var aboutPane: some View {
    VStack(spacing: 13) {
      Button {
        openURL("https://github.com/jx-grxf/MacDev")
      } label: {
        Image(nsImage: appIcon)
          .resizable()
          .frame(width: 96, height: 96)
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
      }
      .buttonStyle(.plain)
      .help("Open MacDev on GitHub")

      VStack(spacing: 3) {
        Text("MacDev")
          .font(.title3.weight(.bold))
        Text("Version \(versionString)")
          .foregroundStyle(.secondary)
        Text("Native macOS menu bar control center for local developer runtimes.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      VStack(spacing: 8) {
        PreferenceLinkRow(systemImage: "chevron.left.slash.chevron.right", title: "GitHub", url: "https://github.com/jx-grxf/MacDev")
        PreferenceLinkRow(systemImage: "globe", title: "Website", url: "https://johannesgrof.me/projects/macdev")
        PreferenceLinkRow(systemImage: "arrow.down.circle", title: "Releases", url: "https://github.com/jx-grxf/MacDev/releases")
      }
      .padding(.top, 6)

      PreferenceDivider()

      VStack(spacing: 10) {
        Toggle("Check for updates automatically", isOn: $appState.automaticallyChecksForUpdates)
          .toggleStyle(.checkbox)

        HStack(spacing: 12) {
          Text("Update Channel")
          Spacer()
          Picker("Update channel", selection: $appState.updateChannel) {
            ForEach(UpdateChannel.allCases) { channel in
              Text(channel.title).tag(channel)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 130)
        }
        .frame(width: 300)

        Text(updateChannelDescription)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 320)

        Button("Check for Updates...") {
          appState.checkForUpdates()
        }
        .disabled(!appState.updatesConfigured)
      }

      Spacer(minLength: 0)

      Text("MIT License")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
    .padding(.top, 4)
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var appIcon: NSImage {
    NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage
  }

  private var versionString: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    if let build, build != version {
      return "\(version) (\(build))"
    }
    return version
  }

  private var updateChannelDescription: String {
    switch appState.updateChannel {
    case .stable:
      "Receive stable GitHub releases only."
    case .beta:
      "Receive stable releases plus beta prereleases."
    }
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

  private func openURL(_ rawValue: String) {
    guard let url = URL(string: rawValue) else { return }
    NSWorkspace.shared.open(url)
  }
}

public enum SettingsPane: String, CaseIterable, Identifiable {
  case general
  case discovery
  case actions
  case notifications
  case updates
  case about

  static let windowHeight: CGFloat = 610

  public var id: String { rawValue }

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

  var preferredWidth: CGFloat {
    switch self {
    case .discovery: 690
    case .notifications, .updates: 620
    case .about: 520
    case .general, .actions: 560
    }
  }
}

private struct PreferencePane<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 16) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
  }
}

private struct PreferenceSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 14) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct PreferenceToggleRow: View {
  let title: String
  let subtitle: String?
  @Binding var isOn: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Toggle(title, isOn: $isOn)
        .toggleStyle(.checkbox)

      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct PreferenceSliderRow: View {
  let title: String
  let subtitle: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let formattedValue: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 18)

      HStack(spacing: 10) {
        Slider(value: $value, in: range, step: step)
          .frame(width: 230)
        Text(formattedValue)
          .font(.body.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(width: 42, alignment: .trailing)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityValue(formattedValue)
  }
}

private struct PreferencePickerRow<Content: View>: View {
  let title: String
  let subtitle: String?
  @ViewBuilder let control: Content

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
        if let subtitle, !subtitle.isEmpty {
          Text(subtitle)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: 18)
      control
    }
  }
}

private struct PreferenceValueRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
      Spacer()
      Text(value)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PreferenceInfoRow: View {
  let systemImage: String
  let title: String
  let subtitle: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: systemImage)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct PreferenceLinkRow: View {
  let systemImage: String
  let title: String
  let url: String
  @State private var isHovering = false

  var body: some View {
    Button {
      guard let url = URL(string: url) else { return }
      NSWorkspace.shared.open(url)
    } label: {
      HStack(spacing: 9) {
        Image(systemName: systemImage)
          .frame(width: 22)
        Text(title)
          .underline(isHovering, color: .accentColor)
      }
      .font(.title3)
      .foregroundStyle(Color.accentColor)
      .frame(maxWidth: 240)
      .padding(.vertical, 3)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
        isHovering = hovering
      }
    }
  }
}

private struct PreferenceDivider: View {
  var body: some View {
    Divider()
      .padding(.vertical, 2)
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
          .font(.body)
          .lineLimit(1)
        Text(profile.path)
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      Text(profile.packageManager.rawValue)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())

      Button(role: .destructive, action: remove) {
        Image(systemName: "trash")
      }
      .buttonStyle(.borderless)
      .labelStyle(.iconOnly)
      .help("Remove profile")
      .accessibilityLabel("Remove \(profile.name)")
    }
    .padding(.vertical, 8)
  }
}

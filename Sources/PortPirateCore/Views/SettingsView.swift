import AppKit
import SwiftUI

public struct SettingsView: View {
  @Bindable private var appState: AppState
  @SceneStorage("settings.selectedPane") private var selectedPaneRaw = SettingsPane.general.rawValue

  public init(appState: AppState) {
    self.appState = appState
  }

  private var selection: Binding<SettingsPane?> {
    Binding(
      get: { SettingsPane(rawValue: selectedPaneRaw) ?? .general },
      set: { selectedPaneRaw = ($0 ?? .general).rawValue }
    )
  }

  public var body: some View {
    NavigationSplitView {
      List(selection: selection) {
        ForEach(SettingsPane.allCases) { pane in
          Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .navigationSplitViewColumnWidth(192)
    } detail: {
      ScrollView {
        pane
          .padding(Theme.s5)
          .frame(maxWidth: 560, alignment: .leading)
          .frame(maxWidth: .infinity)
      }
      .scrollContentBackground(.hidden)
      .translucentWindowBackground(material: .headerView)
    }
    .navigationSplitViewStyle(.balanced)
    .frame(width: SettingsPane.windowWidth, height: SettingsPane.windowHeight)
    .task {
      await appState.loadProfiles()
      await appState.refreshNotificationAuthorization()
    }
  }

  @ViewBuilder
  private var pane: some View {
    switch selection.wrappedValue ?? .general {
    case .general: GeneralPane(appState: appState)
    case .workspaces: WorkspacesPane(appState: appState)
    case .discovery: DiscoveryPane(appState: appState)
    case .notifications: NotificationsPane(appState: appState)
    case .updates: UpdatesPane(appState: appState)
    case .about: AboutPane()
    }
  }
}

public enum SettingsPane: String, CaseIterable, Identifiable {
  case general
  case workspaces
  case discovery
  case notifications
  case updates
  case about

  static let windowWidth: CGFloat = 740
  static let windowHeight: CGFloat = 560

  public var id: String { rawValue }

  var title: String {
    switch self {
    case .general: "General"
    case .workspaces: "Workspaces"
    case .discovery: "Discovery"
    case .notifications: "Notifications"
    case .updates: "Updates"
    case .about: "About"
    }
  }

  var systemImage: String {
    switch self {
    case .general: "gearshape"
    case .workspaces: "folder.badge.gearshape"
    case .discovery: "dot.radiowaves.left.and.right"
    case .notifications: "bell"
    case .updates: "arrow.down.circle"
    case .about: "info.circle"
    }
  }
}

private struct GeneralPane: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(spacing: Theme.s5) {
      SettingsCard(title: "Menu Bar") {
        SettingRow(
          title: "Show runtime count",
          subtitle: "Display the number of visible runtimes next to the menu bar icon."
        ) {
          Toggle("", isOn: $appState.showStatusCount).labelsHidden()
        }

        SettingRow(
          title: "Refresh interval",
          subtitle: "How often PortPirate scans localhost listeners in the background.",
          showsDivider: false
        ) {
          HStack(spacing: Theme.s2) {
            Slider(value: $appState.refreshInterval, in: 2...30, step: 1)
              .frame(width: 150)
            Text("\(Int(appState.refreshInterval))s")
              .font(.body.monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 34, alignment: .trailing)
          }
        }
      }

      SettingsCard(title: "Process Control") {
        SettingRow(
          title: "Confirm before Force Kill",
          subtitle: "Show a confirmation dialog before sending SIGKILL to a process or stopping every service in a stack."
        ) {
          Toggle("", isOn: $appState.confirmForceKill).labelsHidden()
        }

        SettingRow(
          title: "Stop actions are revalidated",
          subtitle: "PortPirate re-checks PID, port, command, owner, and working directory before touching a process.",
          systemImage: "checkmark.shield",
          showsDivider: false
        )
      }
    }
    .toggleStyle(.switch)
  }
}

private struct WorkspacesPane: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.s4) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Workspaces").font(.headline)
          Text("Any folder. PortPirate reads package.json scripts when present, and identifies Swift, Rust, Go, Python, and Ruby projects too.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Button("Add Folder", systemImage: "plus", action: chooseWorkspace)
          .buttonStyle(.borderedProminent)
      }
      .padding(.horizontal, Theme.s2)

      if let message = appState.workspaceMessage {
        WorkspaceMessageBanner(message: message) {
          appState.clearWorkspaceMessage()
        }
      }

      cardBody
    }
  }

  @ViewBuilder
  private var cardBody: some View {
    if appState.profiles.isEmpty {
      ContentUnavailableView {
        Label("No Workspaces", systemImage: "folder.badge.plus")
      } description: {
        Text("Add a project folder. PortPirate keeps track of its scripts, package manager, and expected ports.")
      } actions: {
        Button("Add Folder", action: chooseWorkspace)
          .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, minHeight: 200)
      .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.cardRadius)
          .strokeBorder(Theme.cardStroke, lineWidth: 1)
      )
    } else {
      VStack(spacing: 0) {
        ForEach(appState.profiles) { profile in
          WorkspaceProfileSettingsRow(
            profile: profile,
            showsDivider: profile.id != appState.profiles.last?.id
          ) {
            appState.removeProfile(profile)
          }
        }
      }
      .background(Theme.cardFill, in: .rect(cornerRadius: Theme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.cardRadius)
          .strokeBorder(Theme.cardStroke, lineWidth: 1)
      )
      .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }
  }

  private func chooseWorkspace() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Add"
    panel.title = "Add a workspace folder"

    if panel.runModal() == .OK, let url = panel.url {
      appState.addWorkspace(url: url)
    }
  }
}

private struct WorkspaceMessageBanner: View {
  let message: WorkspaceMessage
  let dismiss: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: Theme.s2) {
      Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .foregroundStyle(message.isError ? Color.yellow : Color.accentColor)
      Text(message.text)
        .font(.callout)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: Theme.s2)
      Button(action: dismiss) {
        Image(systemName: "xmark")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
      .help("Dismiss")
    }
    .padding(Theme.s3)
    .background(
      (message.isError ? Color.yellow : Color.accentColor).opacity(0.12),
      in: .rect(cornerRadius: Theme.rowRadius)
    )
  }
}

private struct DiscoveryPane: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(spacing: Theme.s5) {
      SettingsCard(title: "System Visibility") {
        SettingRow(
          title: "Show Apple services in menu bar",
          subtitle: "Keep AirPlay and other system listeners visible, separated from local runtimes."
        ) {
          Toggle("", isOn: $appState.showAppleServices).labelsHidden()
        }

        SettingRow(
          title: "Show launchd user agents",
          subtitle: "Read-only visibility for user agents. PortPirate does not stop launchd services.",
          showsDivider: false
        ) {
          Toggle("", isOn: $appState.includeLaunchAgents).labelsHidden()
        }
      }

      SettingsCard(title: "Trust") {
        SettingRow(
          title: "System services are blocked from stop actions",
          subtitle: "Apple, Docker, Homebrew, and background listeners stay diagnostic-only unless they are primary local runtimes.",
          systemImage: "lock",
          showsDivider: false
        )
      }
    }
    .toggleStyle(.switch)
  }
}

private struct NotificationsPane: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(spacing: Theme.s5) {
      SettingsCard(title: "Permission") {
        SettingRow(title: "Authorization status", showsDivider: false) {
          Text(appState.notificationAuthorization.title)
            .foregroundStyle(.secondary)
        }
      }

      HStack(spacing: Theme.s2) {
        Button {
          Task { await appState.requestNotifications() }
        } label: {
          Label("Enable Notifications", systemImage: "bell.badge")
        }
        .buttonStyle(.borderedProminent)

        Button {
          Task { await appState.sendTestNotification() }
        } label: {
          Label("Send Test", systemImage: "paperplane")
        }
        Spacer()
      }
      .padding(.horizontal, Theme.s2)

      SettingsCard(title: "Notify Me When") {
        SettingRow(
          title: "A port collision or system warning appears",
          subtitle: "Useful when a server moves ports or a system listener owns a common dev port."
        ) {
          Toggle("", isOn: binding(\.portCollisionsEnabled)).labelsHidden()
        }
        SettingRow(
          title: "A PortPirate-managed process exits with an error",
          subtitle: "Only applies to scripts launched from PortPirate workspaces."
        ) {
          Toggle("", isOn: binding(\.managedProcessCrashEnabled)).labelsHidden()
        }
        SettingRow(
          title: "An expected workspace port is missing",
          subtitle: "Warns when a known project port disappears after refresh."
        ) {
          Toggle("", isOn: binding(\.expectedPortMissingEnabled)).labelsHidden()
        }
        SettingRow(
          title: "A runtime scan fails",
          subtitle: "Surfaces failures from lsof, ps, launchctl, or profile discovery.",
          showsDivider: false
        ) {
          Toggle("", isOn: binding(\.scanFailureEnabled)).labelsHidden()
        }
      }
    }
    .toggleStyle(.switch)
  }

  private func binding(_ keyPath: WritableKeyPath<NotificationSettings, Bool>) -> Binding<Bool> {
    Binding {
      appState.notificationSettings[keyPath: keyPath]
    } set: { value in
      var settings = appState.notificationSettings
      settings[keyPath: keyPath] = value
      appState.notificationSettings = settings
    }
  }
}

private struct UpdatesPane: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(spacing: Theme.s5) {
      SettingsCard(title: "Sparkle Updates") {
        SettingRow(
          title: "Check for updates automatically",
          subtitle: "Uses the signed GitHub Releases appcast when this build includes a Sparkle public key."
        ) {
          Toggle("", isOn: $appState.automaticallyChecksForUpdates).labelsHidden()
        }

        SettingRow(title: "Update channel", subtitle: channelDescription) {
          Picker("", selection: $appState.updateChannel) {
            ForEach(UpdateChannel.allCases) { channel in
              Text(channel.title).tag(channel)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(width: 150)
        }

        SettingRow(title: "Manual check", showsDivider: false) {
          Button("Check for Updates...", systemImage: "arrow.down.circle") {
            appState.checkForUpdates()
          }
          .disabled(!appState.updatesConfigured)
        }
      }

      SettingsCard {
        if appState.updatesConfigured {
          SettingRow(
            title: "Update feed configured",
            subtitle: "Stable receives normal GitHub releases. Beta receives prereleases in addition to stable releases.",
            systemImage: "checkmark.seal",
            showsDivider: false
          )
        } else {
          SettingRow(
            title: "Local build update checks are disabled",
            subtitle: "Package with PORTPIRATE_SPARKLE_PUBLIC_KEY to enable Sparkle in this app bundle.",
            systemImage: "exclamationmark.triangle",
            showsDivider: false
          )
        }
      }
    }
    .toggleStyle(.switch)
  }

  private var channelDescription: String {
    switch appState.updateChannel {
    case .stable: "Receive stable GitHub releases only."
    case .beta: "Receive stable releases plus beta prereleases."
    }
  }
}

private struct AboutPane: View {
  var body: some View {
    VStack(spacing: Theme.s4) {
      Spacer(minLength: Theme.s4)

      Button {
        open("https://github.com/jx-grxf/PortPirate")
      } label: {
        Image(nsImage: appIcon)
          .resizable()
          .frame(width: 104, height: 104)
          .clipShape(RoundedRectangle(cornerRadius: 22))
          .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
      }
      .buttonStyle(.plain)
      .help("Open PortPirate on GitHub")

      VStack(spacing: Theme.s1) {
        Text("PortPirate")
          .font(.title.weight(.bold))
        Text("Version \(versionString)")
          .foregroundStyle(.secondary)
        Text("Tells you which AI agent started that local server.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 360)
      }

      HStack(spacing: Theme.s3) {
        LinkRow(systemImage: "chevron.left.slash.chevron.right", title: "GitHub", url: "https://github.com/jx-grxf/PortPirate")
        LinkRow(systemImage: "globe", title: "Website", url: "https://johannesgrof.me/projects/portpirate")
        LinkRow(systemImage: "arrow.down.circle", title: "Releases", url: "https://github.com/jx-grxf/PortPirate/releases")
      }
      .padding(.top, Theme.s2)

      Spacer(minLength: Theme.s4)

      Text("MIT License")
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

  private func open(_ rawValue: String) {
    guard let url = URL(string: rawValue) else { return }
    NSWorkspace.shared.open(url)
  }
}

private struct LinkRow: View {
  let systemImage: String
  let title: String
  let url: String
  @State private var isHovering = false

  var body: some View {
    Button {
      guard let url = URL(string: url) else { return }
      NSWorkspace.shared.open(url)
    } label: {
      VStack(spacing: Theme.s1 + 1) {
        Image(systemName: systemImage)
          .font(.title3)
        Text(title)
          .font(.callout)
      }
      .foregroundStyle(isHovering ? Color.accentColor : .secondary)
      .frame(width: 96, height: 64)
      .background(
        isHovering ? Theme.hoverFill : Theme.cardFill,
        in: .rect(cornerRadius: Theme.rowRadius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.rowRadius)
          .strokeBorder(Theme.cardStroke, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      withAnimation(Theme.hover) { isHovering = hovering }
    }
  }
}

private struct WorkspaceProfileSettingsRow: View {
  let profile: WorkspaceProfile
  var showsDivider: Bool
  let remove: () -> Void

  @State private var isHovering = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Theme.s3) {
        Image(systemName: "folder")
          .foregroundStyle(.secondary)
          .frame(width: 20)

        VStack(alignment: .leading, spacing: 2) {
          Text(profile.name)
            .lineLimit(1)
          Text(profile.path)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer()

        if !profile.scripts.isEmpty {
          Text("\(profile.scripts.count) script\(profile.scripts.count == 1 ? "" : "s")")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }

        Text(profile.packageManager.label)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .padding(.horizontal, Theme.s2)
          .padding(.vertical, 3)
          .background(.quaternary, in: Capsule())

        Button(role: .destructive, action: remove) {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Remove profile")
        .accessibilityLabel("Remove \(profile.name)")
      }
      .padding(.horizontal, Theme.s3)
      .padding(.vertical, Theme.s3 - 1)
      .background(isHovering ? Theme.hoverFill : AnyShapeStyle(.clear))

      if showsDivider {
        Divider().padding(.leading, Theme.s3)
      }
    }
    .contentShape(.rect)
    .onHover { hovering in
      withAnimation(Theme.hover) { isHovering = hovering }
    }
  }
}

import SwiftUI

public struct RuntimeBrowserView: View {
  @Bindable private var appState: AppState
  @Environment(\.openSettings) private var openSettings
  @State private var searchText = ""

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    NavigationSplitView {
      List(selection: $appState.selectedServerID) {
        Section("Local runtimes") {
          if filteredServers.isEmpty {
            SidebarEmptyRow(searchText: searchText)
          } else {
            ForEach(filteredServers) { server in
              ServerSidebarRow(server: server)
                .tag(server.id)
            }
          }
        }

        if !appState.profiles.isEmpty {
          Section("Workspaces") {
            ForEach(appState.profiles) { profile in
              Label {
                Text(profile.name)
                  .lineLimit(1)
              } icon: {
                Image(systemName: "folder")
              }
              .foregroundStyle(.secondary)
            }
          }
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("MacDev")
      .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
      .searchable(text: $searchText, placement: .sidebar, prompt: "Search runtimes")
      .toolbar {
        ToolbarItem(placement: .status) {
          Text(sidebarStatusText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        ToolbarItem {
          Button("Settings", systemImage: "gearshape") {
            MacDevWindowFocus.activateApp()
            openSettings()
            MacDevWindowFocus.bringSettingsForward()
          }
          .labelStyle(.iconOnly)
          .help("Settings")
        }
        ToolbarItem(placement: .primaryAction) {
          if appState.isRefreshing {
            ProgressView()
              .controlSize(.small)
              .accessibilityLabel("Refreshing")
          } else {
            Button("Refresh", systemImage: "arrow.clockwise") {
              Task { await appState.refresh() }
            }
            .labelStyle(.iconOnly)
            .help("Refresh")
          }
        }
      }
    } detail: {
      if let server = selectedServer {
        ServerInspectorView(appState: appState, server: server)
      } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        ContentUnavailableView(
          "No Runtime Selected",
          systemImage: "server.rack",
          description: Text("Start a local dev server or add a workspace profile.")
        )
      } else {
        ContentUnavailableView.search(text: searchText)
      }
    }
    .navigationSplitViewStyle(.balanced)
    .frame(minWidth: 760, minHeight: 500)
    .task {
      await appState.bootstrap()
    }
  }

  private var filteredServers: [ListeningServer] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return appState.visibleServers }

    return appState.visibleServers.filter { server in
      [
        server.displayTitle,
        server.displayPort,
        server.workspaceName,
        server.runtime.title,
        server.commandLine
      ]
      .contains { $0.lowercased().contains(query) }
    }
  }

  private var selectedServer: ListeningServer? {
    if let selectedServerID = appState.selectedServerID,
       let selectedServer = filteredServers.first(where: { $0.id == selectedServerID }) {
      return selectedServer
    }

    return searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? appState.selectedServer
      : filteredServers.first
  }

  private var sidebarStatusText: String {
    if appState.isRefreshing {
      return "Refreshing"
    }

    let total = appState.visibleServers.count
    let warnings = appState.warningCount
    if total == 0 { return "No runtimes" }
    if warnings == 0 { return "\(total) runtime\(total == 1 ? "" : "s")" }
    return "\(total) runtime\(total == 1 ? "" : "s"), \(warnings) warning\(warnings == 1 ? "" : "s")"
  }
}

private struct ServerSidebarRow: View {
  let server: ListeningServer

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 5) {
          Text(server.displayTitle)
            .lineLimit(1)
          Text(":\(server.displayPort)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }

        Text(server.workspaceName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    } icon: {
      Image(systemName: server.runtime.systemImage)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(server.warning == nil ? Color.secondary : Color.yellow)
    }
    .help("\(server.displayTitle) on localhost:\(server.displayPort)")
  }
}

private struct SidebarEmptyRow: View {
  let searchText: String

  var body: some View {
    Label {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .lineLimit(1)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    } icon: {
      Image(systemName: searchText.isEmpty ? "server.rack" : "magnifyingglass")
        .foregroundStyle(.secondary)
    }
  }

  private var title: String {
    searchText.isEmpty ? "No local runtimes" : "No matching runtimes"
  }

  private var subtitle: String {
    searchText.isEmpty ? "Start a server to see it here." : "Try a port, runtime, command, or workspace."
  }
}

struct ServerInspectorView: View {
  @Bindable var appState: AppState
  let server: ListeningServer
  @State private var showingForceKill = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          StatusDot(server.warning == nil ? .ok : .warning)
          Image(systemName: server.runtime.systemImage)
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
          VStack(alignment: .leading, spacing: 2) {
            Text("\(server.displayTitle) on port \(server.displayPort)")
              .font(.title2)
              .bold()
            Text(server.workspaceName)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }

        HStack {
          Button {
            appState.open(server: server)
          } label: {
            Label("Open", systemImage: "safari")
          }

          Button {
            appState.diagnose(server: server)
          } label: {
            Label("Diagnose", systemImage: "stethoscope")
          }

          Button {
            Task { await appState.stop(server: server, force: false) }
          } label: {
            Label("Stop", systemImage: "stop.circle")
          }

          Button(role: .destructive) {
            requestForceKill()
          } label: {
            Label("Force Kill", systemImage: "xmark.octagon")
          }
        }

        if let warning = server.warning {
          InspectorSection(title: "Warning", systemImage: "exclamationmark.triangle") {
            Text(warning)
              .foregroundStyle(.secondary)
          }
        }

        InspectorSection(title: "Process", systemImage: "cpu") {
          LabeledContent("PID", value: String(server.processID))
          if let parentID = server.process?.parentID {
            LabeledContent("Parent PID", value: String(parentID))
          }
          InspectorTextRow(title: "Command", value: server.commandLine, monospaced: true)
          if let user = server.process?.user {
            LabeledContent("User", value: user)
          }
          if let cwd = server.process?.currentDirectory {
            InspectorTextRow(title: "Working directory", value: cwd)
          }
        }

        InspectorSection(title: "Network", systemImage: "network") {
          LabeledContent("URL", value: "http://localhost:\(server.displayPort)")
          LabeledContent("Addresses", value: server.addresses.joined(separator: ", "))
        }

        if let result = appState.diagnosticResult, result.port == server.port {
          DiagnosticCard(result: result)
        }
      }
      .padding(24)
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

  private func requestForceKill() {
    if appState.confirmForceKill {
      showingForceKill = true
    } else {
      Task { await appState.stop(server: server, force: true) }
    }
  }
}

struct InspectorSection<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: title, systemImage: systemImage)
      VStack(alignment: .leading, spacing: 8) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
  }
}

private struct InspectorTextRow: View {
  let title: String
  let value: String
  var monospaced = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(value)
        .font(monospaced ? .caption.monospaced() : .caption)
        .lineLimit(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

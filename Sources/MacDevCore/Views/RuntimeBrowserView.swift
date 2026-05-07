import SwiftUI

public struct RuntimeBrowserView: View {
  @Bindable private var appState: AppState

  public init(appState: AppState) {
    self.appState = appState
  }

  public var body: some View {
    NavigationSplitView {
      List(selection: $appState.selectedServerID) {
        Section("Local runtimes") {
          ForEach(appState.servers) { server in
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text("\(server.runtime.title) :\(server.port)")
                  .lineLimit(1)
                Text(server.workspaceName)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            } icon: {
              Image(systemName: server.runtime.systemImage)
            }
            .tag(server.id)
          }
        }

        Section("Workspaces") {
          ForEach(appState.profiles) { profile in
            Label(profile.name, systemImage: "folder")
          }
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("MacDev")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            Task { await appState.refresh() }
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh")
        }
      }
    } detail: {
      if let server = appState.selectedServer {
        ServerInspectorView(appState: appState, server: server)
      } else {
        ContentUnavailableView("No Runtime Selected", systemImage: "server.rack")
      }
    }
    .frame(minWidth: 760, minHeight: 500)
    .task {
      appState.startAutoRefresh()
      await appState.loadProfiles()
      await appState.refresh()
    }
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
            Text("\(server.runtime.title) on port \(server.port)")
              .font(.title2)
              .fontWeight(.semibold)
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
            showingForceKill = true
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
          LabeledContent("Command", value: server.commandLine)
          if let user = server.process?.user {
            LabeledContent("User", value: user)
          }
          if let cwd = server.process?.currentDirectory {
            LabeledContent("Working directory", value: cwd)
          }
        }

        InspectorSection(title: "Network", systemImage: "network") {
          LabeledContent("URL", value: "http://localhost:\(server.port)")
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

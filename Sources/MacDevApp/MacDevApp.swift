import MacDevCore
import SwiftUI

@main
struct MacDevApp: App {
  @State private var appState = AppState()

  var body: some Scene {
    MenuBarExtra {
      MenuBarPanelView(appState: appState)
    } label: {
      Label {
        if appState.showStatusCount, !appState.visibleServers.isEmpty {
          Text("\(appState.visibleServers.count)")
        } else {
          Text("MacDev")
        }
      } icon: {
        MenuBarGlyph(state: appState.status)
      }
      .task {
        await appState.bootstrap()
      }
    }
    .menuBarExtraStyle(.window)

    Window("Runtime Browser", id: "runtime-browser") {
      RuntimeBrowserView(appState: appState)
    }
    .defaultSize(width: 860, height: 560)
    .commands {
      MacDevCommands(appState: appState)
    }

    Settings {
      SettingsView(appState: appState)
    }
    .defaultSize(width: 740, height: 560)
    .windowResizability(.contentSize)
  }
}

private struct MacDevCommands: Commands {
  let appState: AppState
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandMenu("MacDev") {
      Button("Refresh") {
        Task { await appState.refresh() }
      }
      .keyboardShortcut("r")

      Button("Runtime Browser") {
        MacDevWindowFocus.activateApp()
        openWindow(id: "runtime-browser")
        MacDevWindowFocus.bringWindowForward(title: "Runtime Browser")
      }
      .keyboardShortcut("b")

      Divider()

      if let server = appState.selectedServer {
        Button("Open Selected Runtime") {
          appState.open(server: server)
        }
        .keyboardShortcut("o")

        Button("Diagnose Selected Runtime") {
          appState.diagnose(server: server)
        }
        .keyboardShortcut("d")
      }
    }
  }
}

private struct MenuBarGlyph: View {
  let state: RuntimeState

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Image(systemName: "terminal")
        .font(.system(size: 15, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(.primary)

      if state == .warning || state == .problem {
        Circle()
          .fill(state == .problem ? .red : .yellow)
          .frame(width: 5, height: 5)
          .offset(x: 2, y: -2)
      }
    }
    .frame(width: 18, height: 18)
    .accessibilityLabel("MacDev \(state.title)")
  }
}

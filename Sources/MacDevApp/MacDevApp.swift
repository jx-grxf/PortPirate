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
        if appState.showStatusCount, !appState.servers.isEmpty {
          Text("\(appState.servers.count)")
        } else {
          Text("MacDev")
        }
      } icon: {
        Image(systemName: statusImage)
          .symbolRenderingMode(.hierarchical)
      }
    }
    .menuBarExtraStyle(.window)

    Window("Runtime Browser", id: "runtime-browser") {
      RuntimeBrowserView(appState: appState)
    }
    .defaultSize(width: 860, height: 560)

    Settings {
      SettingsView(appState: appState)
    }
  }

  private var statusImage: String {
    switch appState.status {
    case .idle: "server.rack"
    case .ok: "checkmark.circle"
    case .warning: "exclamationmark.triangle"
    case .problem: "xmark.octagon"
    }
  }
}

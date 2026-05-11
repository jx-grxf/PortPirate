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
          .fill(state == .problem ? .red : .secondary)
          .frame(width: 5, height: 5)
          .offset(x: 2, y: -2)
      }
    }
    .frame(width: 18, height: 18)
    .accessibilityLabel("MacDev \(state.title)")
  }
}

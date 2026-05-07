import AppKit
import Foundation

@MainActor
public enum MacDevWindowFocus {
  public static func activateApp() {
    NSRunningApplication.current.activate(options: [.activateAllWindows])
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  public static func bringSettingsForward() {
    activateApp()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(120))
      let settingsWindow = NSApplication.shared.windows.first { window in
        window.identifier?.rawValue == "com.apple.SwiftUI.Settings"
          || window.title.localizedCaseInsensitiveContains("settings")
          || window.title.localizedCaseInsensitiveContains("preferences")
      }
      settingsWindow?.orderFrontRegardless()
      settingsWindow?.makeKeyAndOrderFront(nil)
    }
  }

  public static func bringWindowForward(title: String) {
    activateApp()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(120))
      let target = NSApplication.shared.windows.first {
        $0.title.localizedCaseInsensitiveContains(title)
      }
      target?.orderFrontRegardless()
      target?.makeKeyAndOrderFront(nil)
    }
  }
}

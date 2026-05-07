import Foundation

public enum RuntimeClassifier {
  public static func classify(processName: String, command: String, port: Int, currentDirectory: String?) -> RuntimeKind {
    let haystack = "\(processName) \(command) \(currentDirectory ?? "")".lowercased()

    if (port == 5000 || port == 7000), haystack.contains("controlcenter") || haystack.contains("airplay") {
      return .airPlay
    }

    if haystack.contains("vite") { return .vite }
    if haystack.contains("next") { return .next }
    if haystack.contains("astro") { return .astro }
    if haystack.contains("nuxt") { return .nuxt }
    if haystack.contains("bun") { return .bun }
    if haystack.contains("pnpm") { return .pnpm }
    if haystack.contains("yarn") { return .yarn }
    if haystack.contains("npm") { return .npm }
    if haystack.contains("docker") || haystack.contains("com.docker") { return .docker }
    if haystack.contains("homebrew") || haystack.contains("/cellar/") { return .brew }
    if haystack.contains("launchd") { return .launchd }
    if haystack.contains("node") { return .node }

    return .unknown
  }

  public static func warning(for runtime: RuntimeKind, port: Int, command: String) -> String? {
    if runtime == .airPlay {
      return "macOS AirPlay can reserve this port. Do not kill it blindly."
    }

    if port == 5000 || port == 7000 {
      return "This port is commonly used by macOS AirPlay or local web servers."
    }

    if runtime == .unknown {
      return "Unknown listener. Diagnose before stopping."
    }

    if runtime == .vite, port != 5173 {
      return "Vite may have moved because its default port was busy."
    }

    if runtime == .next, port != 3000 {
      return "Next.js usually defaults to 3000 unless configured with PORT or -p."
    }

    if command.lowercased().contains("0.0.0.0") {
      return "This process may be visible to devices on your network."
    }

    return nil
  }
}

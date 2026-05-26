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
    if haystack.contains("openclaw") { return .openClaw }
    if haystack.contains("docker") || haystack.contains("com.docker") { return .docker }

    if isDatabasePort(port) || haystack.contains("postgres")
        || haystack.contains("postmaster")
        || haystack.contains("mysqld") || haystack.contains("mariadb")
        || haystack.contains("redis-server") || haystack.contains("mongod")
        || haystack.contains("clickhouse") || haystack.contains("elasticsearch") {
      return .database
    }

    if haystack.contains("homebrew.mxcl") || haystack.contains("brew services") {
      return .brew
    }
    if haystack.contains("launchd") { return .launchd }
    if haystack.contains("node") { return .node }

    if haystack.contains("python") { return .python }
    if haystack.contains("ruby") || haystack.contains("puma") || haystack.contains("unicorn") || haystack.contains("rails") {
      return .ruby
    }
    if haystack.contains("go-build") || haystack.contains("/go/bin/") {
      return .go
    }
    if haystack.contains("cargo") || haystack.contains("target/debug") || haystack.contains("target/release") {
      return .rust
    }
    if haystack.contains("java") || haystack.contains(".jar") || haystack.contains("gradle") {
      return .java
    }
    if haystack.contains("dotnet") {
      return .dotnet
    }

    return .unknown
  }

  private static func isDatabasePort(_ port: Int) -> Bool {
    switch port {
    case 5432, 5433, 3306, 6379, 27017, 9200, 9300, 8123:
      return true
    default:
      return false
    }
  }

  public static func warning(for runtime: RuntimeKind, port: Int, command: String) -> String? {
    if runtime == .airPlay {
      return "macOS AirPlay can reserve this port. Do not kill it blindly."
    }

    if runtime.isPrimaryRuntime, port == 5000 || port == 7000 {
      return "This port is commonly used by macOS AirPlay or local web servers."
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

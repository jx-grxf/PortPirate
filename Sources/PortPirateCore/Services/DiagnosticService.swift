import Foundation

public enum DiagnosticService {
  public static func diagnose(port: Int, servers: [ListeningServer]) -> DiagnosticResult {
    let matches = servers.filter { $0.port == port }

    guard let server = matches.first else {
      return DiagnosticResult(
        port: port,
        title: "Port \(port) is free",
        cause: "PortPirate did not find a process listening on localhost or any TCP address for this port.",
        recommendedAction: "Start the expected dev server or refresh if it was launched just now.",
        server: nil,
        severity: .idle
      )
    }

    if matches.count > 1 {
      return DiagnosticResult(
        port: port,
        title: "Port \(port) has multiple listeners",
        cause: "More than one process or address entry is associated with this port. This can be IPv4/IPv6 duplication, but different PIDs need attention.",
        recommendedAction: "Inspect the listed PIDs and stop only the process that belongs to the stale workspace.",
        server: server,
        severity: .warning
      )
    }

    switch server.runtime {
    case .airPlay:
      return DiagnosticResult(
        port: port,
        title: "Port \(port) is likely reserved by AirPlay",
        cause: "macOS can reserve ports 5000 and 7000 for AirPlay Receiver or Control Center.",
        recommendedAction: "Disable AirPlay Receiver in System Settings if this port must be used by your dev server.",
        server: server,
        severity: .warning
      )
    case .docker:
      return DiagnosticResult(
        port: port,
        title: "Port \(port) is owned by Docker",
        cause: "A Docker process is listening on this port.",
        recommendedAction: "Prefer stopping the container or compose service instead of killing the PID directly.",
        server: server,
        severity: .warning
      )
    case .brew:
      return DiagnosticResult(
        port: port,
        title: "Port \(port) is owned by a Homebrew service",
        cause: "A Homebrew-managed process appears to own this listener.",
        recommendedAction: "Prefer `brew services stop <service>` when you know the service name.",
        server: server,
        severity: .warning
      )
    case .vite:
      return DiagnosticResult(
        port: port,
        title: "Vite is listening on port \(port)",
        cause: "Vite uses 5173 by default and can move to another port if the default is busy.",
        recommendedAction: "Open the URL or stop the exact PID if this server belongs to an old terminal session.",
        server: server,
        severity: server.warning == nil ? .ok : .warning
      )
    case .next:
      return DiagnosticResult(
        port: port,
        title: "Next.js is listening on port \(port)",
        cause: "Next.js defaults to 3000 unless PORT, -p, or --port changed it.",
        recommendedAction: "Open the URL or stop the exact PID if this is not your active project.",
        server: server,
        severity: server.warning == nil ? .ok : .warning
      )
    default:
      return DiagnosticResult(
        port: port,
        title: "\(server.displayTitle) owns port \(port)",
        cause: "PID \(server.processID) is listening on \(server.addresses.joined(separator: ", ")).",
        recommendedAction: "Verify the command and workspace before stopping the process.",
        server: server,
        severity: server.warning == nil ? .ok : .warning
      )
    }
  }
}

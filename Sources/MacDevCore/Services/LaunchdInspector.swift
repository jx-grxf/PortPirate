import Foundation

public enum LaunchdInspectorParser {
  public static func parse(_ output: String, limit: Int = 80) -> [LaunchAgentInfo] {
    var agents: [LaunchAgentInfo] = []
    var label: String?
    var state: String?
    var path: String?
    var lastExitCode: String?

    func flush() {
      guard let label else { return }
      agents.append(LaunchAgentInfo(label: label, state: state, path: path, lastExitCode: lastExitCode))
    }

    for line in output.split(whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

      if trimmed.hasPrefix("label = ") {
        flush()
        label = String(trimmed.dropFirst("label = ".count))
        state = nil
        path = nil
        lastExitCode = nil
      } else if trimmed.hasPrefix("state = ") {
        state = String(trimmed.dropFirst("state = ".count))
      } else if trimmed.hasPrefix("path = ") || trimmed.hasPrefix("program = ") {
        let value = trimmed
          .replacingOccurrences(of: "path = ", with: "")
          .replacingOccurrences(of: "program = ", with: "")
        path = value
      } else if trimmed.hasPrefix("last exit code = ") {
        lastExitCode = String(trimmed.dropFirst("last exit code = ".count))
      }

      if agents.count >= limit { break }
    }

    flush()
    return Array(agents.prefix(limit))
  }
}

public actor LaunchdInspector {
  private let runner: CommandRunning

  public init(runner: CommandRunning = ShellCommandRunner()) {
    self.runner = runner
  }

  public func userAgents() async -> [LaunchAgentInfo] {
    let uid = getuid()
    do {
      let output = try await runner.run("/bin/launchctl", ["print", "gui/\(uid)"])
      return LaunchdInspectorParser.parse(output)
    } catch {
      return []
    }
  }
}

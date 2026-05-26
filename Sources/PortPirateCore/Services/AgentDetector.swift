import Foundation

public struct AgentDetector: Sendable {
  private let parentExecutableName: @Sendable (pid_t) -> String?

  public init(
    parentExecutableName: @escaping @Sendable (pid_t) -> String? = { pid in
      ProcessInspector.executablePath(for: pid).map {
        URL(fileURLWithPath: $0).lastPathComponent
      }
    }
  ) {
    self.parentExecutableName = parentExecutableName
  }

  public func classify(_ context: ProcessContext) -> ProcessOwner {
    if let owner = ownerFromEnvironment(context.envSubset) {
      return owner
    }

    if let kind = kindFromArguments(context.argv) {
      return .aiAgent(kind: kind, sessionID: nil)
    }

    let parentNames = context.ppidChain.dropFirst().compactMap(parentExecutableName)
    if let kind = kindFromParentExecutableNames(parentNames) {
      return .aiAgent(kind: kind, sessionID: nil)
    }

    if parentNames.contains(where: isInteractiveShell) {
      return .manual
    }

    return .unknown
  }

  private func ownerFromEnvironment(_ environment: [String: String]) -> ProcessOwner? {
    if environment.keys.contains(where: { $0.hasPrefix("CLAUDE_CODE_") }) {
      return .aiAgent(kind: .claudeCode, sessionID: sessionID(in: environment, prefix: "CLAUDE_CODE_"))
    }

    if environment.keys.contains(where: { $0.hasPrefix("CURSOR_") }) {
      return .aiAgent(kind: .cursor, sessionID: sessionID(in: environment, prefix: "CURSOR_"))
    }

    if environment.keys.contains(where: { $0.hasPrefix("CODEX_") }) {
      return .aiAgent(kind: .codex, sessionID: sessionID(in: environment, prefix: "CODEX_"))
    }

    return nil
  }

  private func sessionID(in environment: [String: String], prefix: String) -> String? {
    environment["\(prefix)SESSION_ID"]
      ?? environment.first { key, _ in
        key.hasPrefix(prefix) && key.hasSuffix("_SESSION_ID")
      }?.value
  }

  private func kindFromArguments(_ arguments: [String]) -> AgentKind? {
    let commandLine = arguments.joined(separator: " ").lowercased()
    if commandLine.contains("claude") { return .claudeCode }
    if commandLine.contains("cursor-agent") { return .cursor }
    if commandLine.contains("codex") { return .codex }
    if commandLine.contains("aider") { return .aider }
    if commandLine.contains("windsurf") { return .windsurf }
    return nil
  }

  private func kindFromParentExecutableNames(_ names: [String]) -> AgentKind? {
    for name in names.map({ $0.lowercased() }) {
      if name.contains("claude") { return .claudeCode }
      if name.contains("cursor") { return .cursor }
      if name.contains("codex") { return .codex }
      if name == "code-insiders" { return .other }
      if name.contains("windsurf") { return .windsurf }
    }

    return nil
  }

  private func isInteractiveShell(_ name: String) -> Bool {
    ["bash", "zsh", "fish"].contains(name.lowercased())
  }
}

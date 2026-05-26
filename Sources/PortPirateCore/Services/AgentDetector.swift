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
      return .aiAgent(kind: kind, sessionID: nil, source: .argv)
    }

    let parentNames = context.ppidChain.dropFirst().compactMap(parentExecutableName)
    if let kind = kindFromParentExecutableNames(parentNames) {
      return .aiAgent(kind: kind, sessionID: nil, source: .parentChain)
    }

    if parentNames.contains(where: isInteractiveShell) {
      return .manual
    }

    return .unknown
  }

  private func ownerFromEnvironment(_ environment: [String: String]) -> ProcessOwner? {
    if environment["CLAUDECODE"] == "1"
      || environment.keys.contains(where: { $0.hasPrefix("CLAUDE_CODE_") })
      || environment["AI_AGENT"]?.hasPrefix("claude-code") == true {
      return .aiAgent(
        kind: .claudeCode,
        sessionID: sessionID(in: environment, prefix: "CLAUDE_CODE_"),
        source: .env
      )
    }

    if environment.keys.contains(where: { $0.hasPrefix("CURSOR_") }) {
      return .aiAgent(kind: .cursor, sessionID: sessionID(in: environment, prefix: "CURSOR_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("CODEX_") }) {
      return .aiAgent(kind: .codex, sessionID: sessionID(in: environment, prefix: "CODEX_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("OPENCODE_") }) {
      return .aiAgent(kind: .opencode, sessionID: sessionID(in: environment, prefix: "OPENCODE_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("AIDER_") }) {
      return .aiAgent(kind: .aider, sessionID: sessionID(in: environment, prefix: "AIDER_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("GEMINI_CLI_") }) {
      return .aiAgent(kind: .gemini, sessionID: sessionID(in: environment, prefix: "GEMINI_CLI_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("COPILOT_") }) {
      return .aiAgent(kind: .copilot, sessionID: sessionID(in: environment, prefix: "COPILOT_"), source: .env)
    }

    if environment.keys.contains(where: { $0 == "AUGMENT_AGENT" || $0.hasPrefix("AUGMENT_") }) {
      return .aiAgent(kind: .augment, sessionID: sessionID(in: environment, prefix: "AUGMENT_"), source: .env)
    }

    if environment.keys.contains(where: { $0.hasPrefix("QWEN_CODE_") }) {
      return .aiAgent(kind: .qwenCode, sessionID: sessionID(in: environment, prefix: "QWEN_CODE_"), source: .env)
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
    for name in executableBasenames(arguments) {
      if ["claude", "claude-code"].contains(name) { return .claudeCode }
      if name == "cursor-agent" { return .cursor }
      if name == "codex" { return .codex }
      if name == "aider" { return .aider }
      if name == "windsurf" { return .windsurf }
      if name == "opencode" { return .opencode }
      if ["gemini", "gemini-cli"].contains(name) { return .gemini }
      if name == "copilot" { return .copilot }
      if name == "auggie" { return .augment }
      if ["qwen", "qwen-code"].contains(name) { return .qwenCode }
    }

    return nil
  }

  private func kindFromParentExecutableNames(_ names: [String]) -> AgentKind? {
    for name in names.map({ $0.lowercased() }) {
      if name.contains("claude") { return .claudeCode }
      if name.contains("cursor") { return .cursor }
      if name.contains("codex") { return .codex }
      if name.contains("windsurf") { return .windsurf }
      if name.contains("opencode") { return .opencode }
      if name.contains("gemini") { return .gemini }
      if name.contains("copilot") { return .copilot }
      if name.contains("auggie") || name.contains("augment") { return .augment }
      if name.contains("qwen") { return .qwenCode }
    }

    return nil
  }

  private func executableBasenames(_ arguments: [String]) -> [String] {
    arguments.map { argument in
      URL(fileURLWithPath: argument).lastPathComponent.lowercased()
    }
  }

  private func isInteractiveShell(_ name: String) -> Bool {
    ["bash", "zsh", "fish"].contains(name.lowercased())
  }
}

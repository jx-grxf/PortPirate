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
    var candidates: [(score: Int, owner: ProcessOwner)] = []

    if let match = matchClaudeCode(environment) { candidates.append(match) }
    if let match = matchCursor(environment) { candidates.append(match) }
    if let match = matchCodex(environment) { candidates.append(match) }
    if let match = matchOpencode(environment) { candidates.append(match) }
    if let match = matchAider(environment) { candidates.append(match) }
    if let match = matchGemini(environment) { candidates.append(match) }
    if let match = matchCopilot(environment) { candidates.append(match) }
    if let match = matchAugment(environment) { candidates.append(match) }
    if let match = matchQwen(environment) { candidates.append(match) }
    if let match = matchAntigravity(environment) { candidates.append(match) }
    if let match = matchHermes(environment) { candidates.append(match) }
    if let match = matchOpenClaw(environment) { candidates.append(match) }
    if let match = matchGoose(environment) { candidates.append(match) }
    if let match = matchCline(environment) { candidates.append(match) }
    if let match = matchKimi(environment) { candidates.append(match) }

    if let best = candidates.max(by: { $0.score < $1.score }) {
      return best.owner
    }
    return nil
  }

  private func matchClaudeCode(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if let id = sessionID(in: env, prefix: "CLAUDE_CODE_") {
      return (90, .aiAgent(kind: .claudeCode, sessionID: id, source: .env))
    }
    if env["CLAUDECODE"] == "1"
      || env.keys.contains(where: { $0.hasPrefix("CLAUDE_CODE_") })
      || env["AI_AGENT"]?.hasPrefix("claude-code") == true {
      return (10, .aiAgent(kind: .claudeCode, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchCursor(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if env["CURSOR_TRACE_ID"] != nil || env.keys.contains(where: { $0.hasPrefix("CURSOR_AGENT_") }) {
      return (90, .aiAgent(kind: .cursor, sessionID: sessionID(in: env, prefix: "CURSOR_"), source: .env))
    }
    if env.keys.contains(where: { $0.hasPrefix("CURSOR_") }) {
      return (40, .aiAgent(kind: .cursor, sessionID: sessionID(in: env, prefix: "CURSOR_"), source: .env))
    }
    return nil
  }

  private func matchCodex(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if let id = sessionID(in: env, prefix: "CODEX_") {
      return (90, .aiAgent(kind: .codex, sessionID: id, source: .env))
    }
    if env["OPENAI_CODEX_HOME"] != nil || env.keys.contains(where: { $0.hasPrefix("CODEX_") }) {
      return (60, .aiAgent(kind: .codex, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchOpencode(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if env.keys.contains(where: { $0.hasPrefix("OPENCODE_") }) {
      return (70, .aiAgent(kind: .opencode, sessionID: sessionID(in: env, prefix: "OPENCODE_"), source: .env))
    }
    return nil
  }

  private func matchAider(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = ["AIDER_MODEL", "AIDER_API_KEY", "AIDER_HOME", "AIDER_CONFIG", "AIDER_DARK_MODE"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (70, .aiAgent(kind: .aider, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchGemini(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if let id = sessionID(in: env, prefix: "GEMINI_CLI_") {
      return (90, .aiAgent(kind: .gemini, sessionID: id, source: .env))
    }
    if env.keys.contains(where: { $0.hasPrefix("GEMINI_CLI_") }) {
      return (60, .aiAgent(kind: .gemini, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchCopilot(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if env.keys.contains(where: { $0.hasPrefix("COPILOT_") }) {
      return (60, .aiAgent(kind: .copilot, sessionID: sessionID(in: env, prefix: "COPILOT_"), source: .env))
    }
    return nil
  }

  private func matchAugment(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if env["AUGMENT_AGENT"] != nil {
      return (90, .aiAgent(kind: .augment, sessionID: sessionID(in: env, prefix: "AUGMENT_"), source: .env))
    }
    if env.keys.contains(where: { $0.hasPrefix("AUGMENT_") }) {
      return (60, .aiAgent(kind: .augment, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchQwen(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if env.keys.contains(where: { $0.hasPrefix("QWEN_CODE_") }) {
      return (70, .aiAgent(kind: .qwenCode, sessionID: sessionID(in: env, prefix: "QWEN_CODE_"), source: .env))
    }
    return nil
  }

  private func matchAntigravity(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = ["ANTIGRAVITY_API_KEY", "ANTIGRAVITY_HOME", "ANTIGRAVITY_SESSION_ID", "ANTIGRAVITY_CONFIG"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (80, .aiAgent(kind: .antigravity, sessionID: sessionID(in: env, prefix: "ANTIGRAVITY_"), source: .env))
    }
    return nil
  }

  private func matchHermes(_ env: [String: String]) -> (Int, ProcessOwner)? {
    if let id = env["HERMES_SESSION_ID"] {
      return (95, .aiAgent(kind: .hermes, sessionID: id, source: .env))
    }
    let markers: Set<String> = ["HERMES_HOME", "HERMES_KANBAN_TASK", "HERMES_KANBAN_BOARD"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (70, .aiAgent(kind: .hermes, sessionID: nil, source: .env))
    }
    return nil
  }

  private func matchOpenClaw(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = [
      "OPENCLAW_HOME", "OPENCLAW_SESSION_ID", "OPENCLAW_AGENT", "OPENCLAW_AGENT_ID",
      "OPENCLAW_WORKSPACE", "OPENCLAW_PROFILE", "OPENCLAW_CONFIG"
    ]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (80, .aiAgent(kind: .openclaw, sessionID: sessionID(in: env, prefix: "OPENCLAW_"), source: .env))
    }
    return nil
  }

  private func matchGoose(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = ["GOOSE_PROVIDER", "GOOSE_MODEL", "GOOSE_SESSION_ID", "GOOSE_HOME", "GOOSE_CONFIG"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (80, .aiAgent(kind: .goose, sessionID: sessionID(in: env, prefix: "GOOSE_"), source: .env))
    }
    return nil
  }

  private func matchCline(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = ["CLINE_DIR", "CLINE_SHELL", "CLINE_COMMAND_PERMISSIONS", "CLINE_ACTIVE", "CLINE_SESSION_ID"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (80, .aiAgent(kind: .cline, sessionID: sessionID(in: env, prefix: "CLINE_"), source: .env))
    }
    return nil
  }

  private func matchKimi(_ env: [String: String]) -> (Int, ProcessOwner)? {
    let markers: Set<String> = ["KIMI_SHARE_DIR", "KIMI_HOME", "KIMI_SESSION_ID", "KIMI_API_KEY"]
    if env.keys.contains(where: { markers.contains($0) }) {
      return (80, .aiAgent(kind: .kimi, sessionID: sessionID(in: env, prefix: "KIMI_"), source: .env))
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
    for name in agentCandidateBasenames(arguments) {
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
      if ["agy", "antigravity"].contains(name) { return .antigravity }
      if name == "hermes" { return .hermes }
      if name == "openclaw" { return .openclaw }
      if name == "goose" { return .goose }
      if name == "cline" { return .cline }
      if ["kimi", "kimi-cli"].contains(name) { return .kimi }
    }
    return nil
  }

  private func kindFromParentExecutableNames(_ names: [String]) -> AgentKind? {
    for raw in names {
      let name = URL(fileURLWithPath: raw).lastPathComponent.lowercased()
      if ["claude", "claude-code"].contains(name) { return .claudeCode }
      if ["cursor-agent"].contains(name) { return .cursor }
      if name == "codex" { return .codex }
      if name == "windsurf" { return .windsurf }
      if name == "opencode" { return .opencode }
      if ["gemini", "gemini-cli"].contains(name) { return .gemini }
      if name == "copilot" { return .copilot }
      if ["auggie", "augment"].contains(name) { return .augment }
      if ["qwen", "qwen-code"].contains(name) { return .qwenCode }
      if name == "aider" { return .aider }
      if ["agy", "antigravity"].contains(name) { return .antigravity }
      if name == "hermes" { return .hermes }
      if name == "openclaw" { return .openclaw }
      if name == "goose" { return .goose }
      if name == "cline" { return .cline }
      if ["kimi", "kimi-cli"].contains(name) { return .kimi }
    }

    return nil
  }

  private func agentCandidateBasenames(_ arguments: [String]) -> [String] {
    let interpreters: Set<String> = ["python", "python3", "node", "npx", "bunx", "uvx", "pnpx", "ruby"]
    var result: [String] = []
    var skipNext = false
    for (index, raw) in arguments.enumerated() {
      let name = URL(fileURLWithPath: raw).lastPathComponent.lowercased()
      if skipNext { skipNext = false; continue }
      result.append(name)
      if interpreters.contains(name), index + 1 < arguments.count {
        let next = arguments[index + 1]
        if next == "-m" || next == "-c" { skipNext = true; continue }
        let nextName = URL(fileURLWithPath: next).lastPathComponent.lowercased()
        result.append(nextName)
      }
    }
    return result
  }

  private func isInteractiveShell(_ name: String) -> Bool {
    ["bash", "zsh", "fish"].contains(name.lowercased())
  }
}

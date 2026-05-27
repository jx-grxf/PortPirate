import Foundation

public enum DetectionSource: String, Codable, Sendable, CaseIterable {
  case env
  case parentChain
  case argv
}

public enum ProcessOwner: Equatable, Hashable, Codable, Sendable {
  case aiAgent(kind: AgentKind, sessionID: String?, source: DetectionSource)
  case manual
  case unknown
}

public enum AgentKind: String, Codable, Sendable {
  case claudeCode
  case cursor
  case codex
  case windsurf
  case aider
  case opencode
  case gemini
  case copilot
  case augment
  case qwenCode
  case antigravity
  case goose
  case cline
  case kimi
  case hermes
  case openclaw
  case other

  public var category: AgentCategory {
    switch self {
    case .hermes, .openclaw: return .assistant
    default: return .coding
    }
  }
}

public enum AgentCategory: String, Codable, Sendable {
  case coding
  case assistant
}

import Foundation

public enum RuntimeState: String, Codable, Sendable {
  case idle
  case ok
  case warning
  case problem

  public var title: String {
    switch self {
    case .idle: "Idle"
    case .ok: "Running"
    case .warning: "Warning"
    case .problem: "Problem"
    }
  }
}

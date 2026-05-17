import Foundation

public enum UpdateChannel: String, CaseIterable, Codable, Identifiable, Sendable {
  case stable
  case beta

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .stable: "Stable"
    case .beta: "Beta"
    }
  }

  public var allowedChannels: Set<String> {
    switch self {
    case .stable: []
    case .beta: ["beta"]
    }
  }
}

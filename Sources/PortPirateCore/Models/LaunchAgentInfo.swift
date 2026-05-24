import Foundation

public struct LaunchAgentInfo: Identifiable, Hashable, Sendable {
  public let id: String
  public let label: String
  public let state: String?
  public let path: String?
  public let lastExitCode: String?

  public init(label: String, state: String?, path: String?, lastExitCode: String?) {
    self.id = label
    self.label = label
    self.state = state
    self.path = path
    self.lastExitCode = lastExitCode
  }
}

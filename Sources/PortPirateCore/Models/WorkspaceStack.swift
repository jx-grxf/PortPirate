import Foundation

public struct WorkspaceStack: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  public let repoRoot: URL
  public let branch: String?
  public let hasMixedBranches: Bool
  public let isWorktree: Bool
  public let servers: [ListeningServer]

  public init(
    name: String,
    repoRoot: URL,
    branch: String?,
    hasMixedBranches: Bool,
    isWorktree: Bool,
    servers: [ListeningServer]
  ) {
    self.id = repoRoot.path
    self.name = name
    self.repoRoot = repoRoot
    self.branch = branch
    self.hasMixedBranches = hasMixedBranches
    self.isWorktree = isWorktree
    self.servers = servers
  }

  public var status: RuntimeState {
    if servers.contains(where: { $0.warning != nil }) { return .warning }
    if servers.isEmpty { return .idle }
    return .ok
  }

  public var primaryRuntimeCount: Int {
    servers.filter(\.isPrimaryRuntime).count
  }
}

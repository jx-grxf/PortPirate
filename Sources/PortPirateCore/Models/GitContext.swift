import Foundation

public struct GitContext: Equatable, Hashable, Codable, Sendable {
  public let repoRoot: URL
  public let branch: String?
  public let worktreePath: URL?
  public let isWorktree: Bool

  public init(repoRoot: URL, branch: String?, worktreePath: URL?, isWorktree: Bool) {
    self.repoRoot = repoRoot
    self.branch = branch
    self.worktreePath = worktreePath
    self.isWorktree = isWorktree
  }
}

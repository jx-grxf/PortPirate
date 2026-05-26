import Foundation

public enum StackGrouper {
  public struct GroupedServers: Sendable {
    public let stacks: [WorkspaceStack]
    public let ungrouped: [ListeningServer]

    public init(stacks: [WorkspaceStack], ungrouped: [ListeningServer]) {
      self.stacks = stacks
      self.ungrouped = ungrouped
    }
  }

  public static func group(_ servers: [ListeningServer], minimumServices: Int = 2) -> GroupedServers {
    var byKey: [URL: [ListeningServer]] = [:]
    var ungrouped: [ListeningServer] = []
    var keyOrder: [URL] = []

    for server in servers {
      guard let key = stackKey(for: server) else {
        ungrouped.append(server)
        continue
      }
      if byKey[key] == nil {
        keyOrder.append(key)
        byKey[key] = []
      }
      byKey[key]?.append(server)
    }

    var stacks: [WorkspaceStack] = []
    for key in keyOrder {
      let group = byKey[key] ?? []
      if group.count < minimumServices {
        ungrouped.append(contentsOf: group)
        continue
      }
      stacks.append(makeStack(rootKey: key, servers: group))
    }

    stacks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    ungrouped.sort {
      if $0.port == $1.port { return $0.processID < $1.processID }
      return $0.port < $1.port
    }

    return GroupedServers(stacks: stacks, ungrouped: ungrouped)
  }

  private static func stackKey(for server: ListeningServer) -> URL? {
    guard let context = server.process?.gitContext else { return nil }
    return context.worktreePath ?? context.repoRoot
  }

  private static func makeStack(rootKey: URL, servers: [ListeningServer]) -> WorkspaceStack {
    let branches = Set(servers.compactMap { $0.process?.gitContext?.branch })
      .filter { !$0.isEmpty }
    let branch: String?
    let mixed: Bool
    if branches.count <= 1 {
      branch = branches.first
      mixed = false
    } else {
      branch = nil
      mixed = true
    }

    let isWorktree = servers.contains { $0.process?.gitContext?.isWorktree == true }
    let sortedServers = servers.sorted {
      if $0.port == $1.port { return $0.processID < $1.processID }
      return $0.port < $1.port
    }

    return WorkspaceStack(
      name: rootKey.lastPathComponent,
      repoRoot: rootKey,
      branch: branch,
      hasMixedBranches: mixed,
      isWorktree: isWorktree,
      servers: sortedServers
    )
  }
}

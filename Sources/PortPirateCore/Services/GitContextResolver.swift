import Foundation

public struct GitContextResolver: Sendable {
  public init() {}

  public func resolve(cwd: URL) -> GitContext? {
    guard let gitReference = findGitReference(startingAt: cwd.standardizedFileURL) else {
      return nil
    }

    switch gitReference.kind {
    case .directory:
      return GitContext(
        repoRoot: gitReference.repoRoot,
        branch: branchName(gitDirectory: gitReference.gitPath),
        worktreePath: nil,
        isWorktree: false
      )
    case .file:
      guard let gitDirectory = gitDirectory(from: gitReference.gitPath, relativeTo: gitReference.repoRoot) else {
        return nil
      }

      return GitContext(
        repoRoot: gitReference.repoRoot,
        branch: branchName(gitDirectory: gitDirectory),
        worktreePath: gitReference.repoRoot,
        isWorktree: true
      )
    }
  }

  private func findGitReference(startingAt start: URL) -> GitReference? {
    var current = start

    while true {
      let candidate = current.appendingPathComponent(".git")
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
        return GitReference(
          repoRoot: current,
          gitPath: candidate,
          kind: isDirectory.boolValue ? .directory : .file
        )
      }

      let parent = current.deletingLastPathComponent()
      if parent.path == current.path { return nil }
      current = parent
    }
  }

  private func gitDirectory(from gitFile: URL, relativeTo repoRoot: URL) -> URL? {
    guard
      let contents = try? String(contentsOf: gitFile, encoding: .utf8),
      let line = contents.split(whereSeparator: \.isNewline).first,
      line.hasPrefix("gitdir:")
    else {
      return nil
    }

    let path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespacesAndNewlines)
    let url = URL(fileURLWithPath: path, relativeTo: path.hasPrefix("/") ? nil : repoRoot)
    return url.standardizedFileURL
  }

  private func branchName(gitDirectory: URL) -> String? {
    guard let head = try? String(contentsOf: gitDirectory.appendingPathComponent("HEAD"), encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    else {
      return nil
    }

    if head.hasPrefix("ref: refs/heads/") {
      return String(head.dropFirst("ref: refs/heads/".count))
    }

    return head.isEmpty ? nil : head
  }

  private struct GitReference {
    let repoRoot: URL
    let gitPath: URL
    let kind: GitReferenceKind
  }

  private enum GitReferenceKind {
    case directory
    case file
  }
}

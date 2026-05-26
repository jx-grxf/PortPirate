import XCTest
@testable import PortPirateCore

final class StackGrouperTests: XCTestCase {
  func testGroupsServersSharingARepoRoot() {
    let repo = URL(fileURLWithPath: "/Users/me/code/api")
    let result = StackGrouper.group([
      makeServer(port: 3000, repoRoot: repo, branch: "main"),
      makeServer(port: 8000, repoRoot: repo, branch: "main")
    ])

    XCTAssertEqual(result.stacks.count, 1)
    XCTAssertTrue(result.ungrouped.isEmpty)

    let stack = try! XCTUnwrap(result.stacks.first)
    XCTAssertEqual(stack.name, "api")
    XCTAssertEqual(stack.branch, "main")
    XCTAssertFalse(stack.hasMixedBranches)
    XCTAssertEqual(stack.servers.map(\.port), [3000, 8000])
  }

  func testSingleServerRepoIsNotAStack() {
    let repo = URL(fileURLWithPath: "/Users/me/code/solo")
    let result = StackGrouper.group([
      makeServer(port: 3000, repoRoot: repo, branch: "main")
    ])

    XCTAssertTrue(result.stacks.isEmpty)
    XCTAssertEqual(result.ungrouped.count, 1)
  }

  func testServersWithoutGitContextStayUngrouped() {
    let result = StackGrouper.group([
      makeServer(port: 9090, repoRoot: nil),
      makeServer(port: 9091, repoRoot: nil)
    ])

    XCTAssertTrue(result.stacks.isEmpty)
    XCTAssertEqual(result.ungrouped.count, 2)
  }

  func testFlagsMixedBranches() {
    let repo = URL(fileURLWithPath: "/Users/me/code/mixed")
    let result = StackGrouper.group([
      makeServer(port: 3000, repoRoot: repo, branch: "main"),
      makeServer(port: 8000, repoRoot: repo, branch: "feat/x")
    ])

    let stack = try! XCTUnwrap(result.stacks.first)
    XCTAssertTrue(stack.hasMixedBranches)
    XCTAssertNil(stack.branch)
  }

  func testWorktreesGroupByWorktreePathNotRepoRoot() {
    let mainRepo = URL(fileURLWithPath: "/Users/me/code/api")
    let worktreeA = URL(fileURLWithPath: "/Users/me/worktrees/api-cc1")
    let worktreeB = URL(fileURLWithPath: "/Users/me/worktrees/api-cc2")

    let result = StackGrouper.group([
      makeServer(port: 3000, repoRoot: mainRepo, worktreePath: worktreeA, isWorktree: true, branch: "feat/a"),
      makeServer(port: 8000, repoRoot: mainRepo, worktreePath: worktreeA, isWorktree: true, branch: "feat/a"),
      makeServer(port: 3001, repoRoot: mainRepo, worktreePath: worktreeB, isWorktree: true, branch: "feat/b"),
      makeServer(port: 8001, repoRoot: mainRepo, worktreePath: worktreeB, isWorktree: true, branch: "feat/b")
    ])

    XCTAssertEqual(result.stacks.count, 2)
    XCTAssertTrue(result.stacks.allSatisfy { $0.isWorktree })
    XCTAssertEqual(Set(result.stacks.map(\.name)), ["api-cc1", "api-cc2"])
  }

  func testKeepsMultipleRepos() {
    let repoA = URL(fileURLWithPath: "/Users/me/code/a")
    let repoB = URL(fileURLWithPath: "/Users/me/code/b")
    let result = StackGrouper.group([
      makeServer(port: 3000, repoRoot: repoA, branch: "main"),
      makeServer(port: 3001, repoRoot: repoA, branch: "main"),
      makeServer(port: 4000, repoRoot: repoB, branch: "main"),
      makeServer(port: 4001, repoRoot: repoB, branch: "main"),
      makeServer(port: 9999, repoRoot: nil)
    ])

    XCTAssertEqual(result.stacks.count, 2)
    XCTAssertEqual(result.ungrouped.count, 1)
    XCTAssertEqual(result.stacks.map(\.name), ["a", "b"])
  }

  private func makeServer(
    port: Int,
    repoRoot: URL?,
    worktreePath: URL? = nil,
    isWorktree: Bool = false,
    branch: String? = nil
  ) -> ListeningServer {
    let git = repoRoot.map { root in
      GitContext(repoRoot: root, branch: branch, worktreePath: worktreePath, isWorktree: isWorktree)
    }
    let process = PortPirateProcess(
      id: Int32(port),
      parentID: nil,
      user: "tester",
      command: "node",
      currentDirectory: repoRoot?.path,
      owner: .unknown,
      gitContext: git,
      startedAt: nil
    )
    return ListeningServer(
      port: port,
      addresses: ["127.0.0.1"],
      processID: Int32(port),
      processName: "node",
      process: process,
      runtime: .node,
      warning: nil
    )
  }
}

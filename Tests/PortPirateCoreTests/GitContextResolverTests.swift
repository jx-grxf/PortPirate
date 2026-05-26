import XCTest
@testable import PortPirateCore

final class GitContextResolverTests: XCTestCase {
  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    try super.tearDownWithError()
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
  }

  func testResolvesRegularRepositoryBranch() throws {
    let root = try makeTemporaryDirectory()
    let repo = root.appendingPathComponent("repo")
    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    try runGit(["init"], cwd: repo)
    try runGit(["checkout", "-b", "main"], cwd: repo)

    let context = GitContextResolver().resolve(cwd: repo)

    XCTAssertEqual(context?.repoRoot.standardizedFileURL, repo.standardizedFileURL)
    XCTAssertEqual(context?.branch, "main")
    XCTAssertEqual(context?.isWorktree, false)
    XCTAssertNil(context?.worktreePath)
  }

  func testResolvesWorktreeBranch() throws {
    let root = try makeTemporaryDirectory()
    let repo = root.appendingPathComponent("repo")
    let worktree = root.appendingPathComponent("worktree")
    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    try runGit(["init"], cwd: repo)
    try runGit(["checkout", "-b", "main"], cwd: repo)
    try "initial\n".write(to: repo.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    try runGit(["add", "README.md"], cwd: repo)
    try runGit(["-c", "user.name=PortPirate Tests", "-c", "user.email=tests@example.invalid", "commit", "-m", "initial"], cwd: repo)
    try runGit(["worktree", "add", "-b", "feature/context", worktree.path], cwd: repo)

    let context = GitContextResolver().resolve(cwd: worktree)

    XCTAssertEqual(context?.repoRoot.standardizedFileURL, worktree.standardizedFileURL)
    XCTAssertEqual(context?.branch, "feature/context")
    XCTAssertEqual(context?.isWorktree, true)
    XCTAssertEqual(context?.worktreePath?.standardizedFileURL, worktree.standardizedFileURL)
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("PortPirateTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }

  private func runGit(_ arguments: [String], cwd: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = cwd

    let errorPipe = Pipe()
    let outputPipe = Pipe()
    process.standardError = errorPipe
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      XCTFail("git \(arguments.joined(separator: " ")) failed: \(error)")
      return
    }
  }
}

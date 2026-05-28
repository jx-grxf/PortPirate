import XCTest
@testable import PortPirateCore

final class WorkspaceProcessScannerTests: XCTestCase {
  func testParsesPSRowsWithStartDateAndCommand() {
    let output = "43814 26205 Tue May 26 19:49:10 2026 npm run dev\n"
    let rows = WorkspaceProcessScannerParser.parsePS(output)

    XCTAssertEqual(rows.count, 1)
    XCTAssertEqual(rows[0].pid, 43814)
    XCTAssertEqual(rows[0].parentID, 26205)
    XCTAssertEqual(rows[0].command, "npm run dev")
    XCTAssertNotNil(rows[0].startedAt)
  }

  func testParsesCurrentDirectories() {
    let output = """
    p43814
    cnode
    fcwd
    n/Users/me/app
    p43834
    fcwd
    n/Users/me/app/packages/worker
    """

    XCTAssertEqual(
      WorkspaceProcessScannerParser.parseCurrentDirectories(output),
      [
        43814: "/Users/me/app",
        43834: "/Users/me/app/packages/worker"
      ]
    )
  }

  func testScanDetectsOrphanedProjectNodeChildAsWorkspaceScript() async {
    let profile = WorkspaceProfile(
      id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
      name: "hermes-discord-voice",
      path: "/Users/me/Hermes-Discord-Voice",
      packageManager: .npm,
      scripts: [
        PackageScript(name: "dev", command: "node scripts/run-with-project-node.cjs tsx src/index.ts")
      ]
    )
    let runner = FakeWorkspaceCommandRunner(outputs: [
      "/bin/ps": """
      43836 1 Tue May 26 19:49:10 2026 node /Users/me/Hermes-Discord-Voice/node_modules/.bin/tsx src/index.ts
      43844 43836 Tue May 26 19:49:11 2026 /opt/homebrew/bin/node --require /Users/me/Hermes-Discord-Voice/node_modules/tsx/dist/preflight.cjs --import file:///Users/me/Hermes-Discord-Voice/node_modules/tsx/dist/loader.mjs src/index.ts
      43847 43844 Tue May 26 19:49:11 2026 /Users/me/Hermes-Discord-Voice/node_modules/@esbuild/darwin-arm64/bin/esbuild --service=0.27.3 --ping
      """,
      "/usr/sbin/lsof": """
      p43836
      cnode
      fcwd
      n/Users/me/Hermes-Discord-Voice
      p43844
      cnode
      fcwd
      n/Users/me/Hermes-Discord-Voice
      p43847
      cesbuild
      fcwd
      n/Users/me/Hermes-Discord-Voice
      """
    ])
    let scanner = WorkspaceProcessScanner(runner: runner, lsofPath: "/usr/sbin/lsof")

    let scripts = await scanner.scan(profiles: [profile])

    XCTAssertEqual(scripts.count, 1)
    XCTAssertEqual(scripts[0].profileID, profile.id)
    XCTAssertEqual(scripts[0].scriptName, "dev")
    XCTAssertEqual(scripts[0].processID, 43836)
    XCTAssertTrue(scripts[0].isRunning)
    XCTAssertFalse(scripts[0].isManaged)
  }

  func testScanDetectsPackageScriptWithoutStoredWorkspaceProfile() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try """
    {
      "name": "live-app",
      "scripts": {
        "dev": "node scripts/run-with-project-node.cjs tsx src/index.ts"
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let runner = FakeWorkspaceCommandRunner(outputs: [
      "/bin/ps": "321 1 Wed May 27 10:34:00 2026 node \(directory.path)/node_modules/.bin/tsx src/index.ts\n",
      "/usr/sbin/lsof": """
      p321
      cnode
      fcwd
      n\(directory.path)
      """
    ])
    let scanner = WorkspaceProcessScanner(runner: runner, lsofPath: "/usr/sbin/lsof")

    let scripts = await scanner.scan(profiles: [])

    XCTAssertEqual(scripts.count, 1)
    XCTAssertEqual(scripts[0].profileName, "live-app")
    XCTAssertEqual(scripts[0].scriptName, "dev")
    XCTAssertEqual(scripts[0].processID, 321)
    XCTAssertTrue(scripts[0].isRunning)
    XCTAssertFalse(scripts[0].isManaged)
  }

  func testScanChoosesMostSpecificNestedWorkspaceProfile() async {
    let parent = WorkspaceProfile(
      id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
      name: "parent",
      path: "/Users/me",
      packageManager: .npm,
      scripts: [PackageScript(name: "dev", command: "vite")]
    )
    let child = WorkspaceProfile(
      id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
      name: "child",
      path: "/Users/me/app",
      packageManager: .npm,
      scripts: [PackageScript(name: "dev", command: "vite")]
    )
    let runner = FakeWorkspaceCommandRunner(outputs: [
      "/bin/ps": "123 1 Wed May 27 09:00:00 2026 vite --host 0.0.0.0\n",
      "/usr/sbin/lsof": """
      p123
      cvite
      fcwd
      n/Users/me/app
      """
    ])
    let scanner = WorkspaceProcessScanner(runner: runner, lsofPath: "/usr/sbin/lsof")

    let scripts = await scanner.scan(profiles: [parent, child])

    XCTAssertEqual(scripts.first?.profileID, child.id)
  }
}

private struct FakeWorkspaceCommandRunner: CommandRunning {
  let outputs: [String: String]

  func run(_ executable: String, _ arguments: [String]) async throws -> String {
    outputs[executable] ?? ""
  }
}

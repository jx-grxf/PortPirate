import XCTest
@testable import PortPirateCore

final class AppStateFiltersTests: XCTestCase {
  func testIsAIAgentDetectsClassifiedOwners() {
    let agent = makeServer(processID: 1, owner: .aiAgent(kind: .claudeCode, sessionID: nil, source: .env))
    let manual = makeServer(processID: 2, owner: .manual)
    let unknown = makeServer(processID: 3, owner: .unknown)

    XCTAssertTrue(AppState.isAIAgent(agent))
    XCTAssertFalse(AppState.isAIAgent(manual))
    XCTAssertFalse(AppState.isAIAgent(unknown))
  }

  func testIsStaleUsesThirtyMinuteThreshold() {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let young = makeServer(processID: 1, startedAt: now.addingTimeInterval(-29 * 60))
    let old = makeServer(processID: 2, startedAt: now.addingTimeInterval(-31 * 60))
    let missing = makeServer(processID: 3, startedAt: nil)

    XCTAssertFalse(AppState.isStale(young, now: now))
    XCTAssertTrue(AppState.isStale(old, now: now))
    XCTAssertFalse(AppState.isStale(missing, now: now))
  }

  func testRelativeAgeShortFormatting() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    XCTAssertNil(RelativeAge.short(from: nil, now: now))
    XCTAssertEqual(RelativeAge.short(from: now.addingTimeInterval(-5), now: now), "5s")
    XCTAssertEqual(RelativeAge.short(from: now.addingTimeInterval(-90), now: now), "1m")
    XCTAssertEqual(RelativeAge.short(from: now.addingTimeInterval(-3 * 3600), now: now), "3h")
    XCTAssertEqual(RelativeAge.short(from: now.addingTimeInterval(-2 * 86_400), now: now), "2d")
  }

  func testOwnerPresentationOnlyExistsForAIAgents() {
    let agentServer = makeServer(
      processID: 1,
      owner: .aiAgent(kind: .cursor, sessionID: "abc", source: .parentChain),
      currentDirectory: "/Users/me/repo"
    )
    let manualServer = makeServer(processID: 2, owner: .manual)

    let presentation = OwnerPresentation(server: agentServer)
    XCTAssertEqual(presentation?.label, "Cursor")
    XCTAssertEqual(presentation?.source, .parentChain)
    XCTAssertTrue(presentation?.tooltip.contains("session abc") ?? false)
    XCTAssertTrue(presentation?.tooltip.contains("/Users/me/repo") ?? false)
    XCTAssertTrue(presentation?.tooltip.contains("parent process chain") ?? false)

    XCTAssertNil(OwnerPresentation(server: manualServer))
  }

  func testWorkspaceProfileCanPromoteUnknownExpectedPortToDeveloperRuntime() {
    let profiles = [
      WorkspaceProfile(
        name: "sample-app",
        path: "/Users/me/sample-app",
        packageManager: .pnpm,
        scripts: [PackageScript(name: "dev", command: "vite")],
        expectedPorts: [5173]
      )
    ]
    let matching = makeServer(
      processID: 10,
      port: 5173,
      runtime: .unknown,
      currentDirectory: "/Users/me/sample-app/packages/web"
    )
    let wrongPort = makeServer(
      processID: 11,
      port: 3000,
      runtime: .unknown,
      currentDirectory: "/Users/me/sample-app"
    )

    XCTAssertTrue(AppState.isWorkspaceProfileRuntime(matching, profiles: profiles))
    XCTAssertFalse(AppState.isWorkspaceProfileRuntime(wrongPort, profiles: profiles))
  }

  func testRefreshedProfilesPreserveIDsAndReloadPackageMetadata() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try """
    {
      "name": "fresh-app",
      "packageManager": "pnpm@10.0.0",
      "scripts": {
        "dev": "vite --port 5174"
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

    let originalID = UUID()
    let stale = WorkspaceProfile(
      id: originalID,
      name: "stale-app",
      path: directory.path,
      packageManager: .npm,
      scripts: [],
      expectedPorts: []
    )

    let refreshed = try XCTUnwrap(AppState.refreshedProfiles([stale]).first)
    XCTAssertEqual(refreshed.id, originalID)
    XCTAssertEqual(refreshed.name, "fresh-app")
    XCTAssertEqual(refreshed.packageManager, .pnpm)
    XCTAssertEqual(refreshed.scripts.map(\.name), ["dev"])
    XCTAssertEqual(refreshed.expectedPorts, [5173, 5174])
  }

  private func makeServer(
    processID: Int32,
    port: Int = 3000,
    runtime: RuntimeKind = .node,
    owner: ProcessOwner = .unknown,
    startedAt: Date? = nil,
    currentDirectory: String? = nil
  ) -> ListeningServer {
    let process = PortPirateProcess(
      id: processID,
      parentID: nil,
      user: "tester",
      command: "node server.js",
      currentDirectory: currentDirectory,
      owner: owner,
      gitContext: nil,
      startedAt: startedAt
    )
    return ListeningServer(
      port: port,
      addresses: ["127.0.0.1"],
      processID: processID,
      processName: "node",
      process: process,
      runtime: runtime,
      warning: nil
    )
  }
}

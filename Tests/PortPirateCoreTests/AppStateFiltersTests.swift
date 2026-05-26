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

  private func makeServer(
    processID: Int32,
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
      port: 3000,
      addresses: ["127.0.0.1"],
      processID: processID,
      processName: "node",
      process: process,
      runtime: .node,
      warning: nil
    )
  }
}

import XCTest
@testable import MacDevCore

final class LaunchdInspectorParserTests: XCTestCase {
  func testParsesLaunchctlLikeBlocks() {
    let output = """
    label = com.example.agent
    state = running
    program = /Users/example/bin/agent
    last exit code = 0
    label = com.example.second
    path = /Users/example/Library/LaunchAgents/com.example.second.plist
    """

    let agents = LaunchdInspectorParser.parse(output)

    XCTAssertEqual(agents.count, 2)
    XCTAssertEqual(agents[0].label, "com.example.agent")
    XCTAssertEqual(agents[0].state, "running")
    XCTAssertEqual(agents[0].path, "/Users/example/bin/agent")
    XCTAssertEqual(agents[0].lastExitCode, "0")
    XCTAssertEqual(agents[1].label, "com.example.second")
  }
}

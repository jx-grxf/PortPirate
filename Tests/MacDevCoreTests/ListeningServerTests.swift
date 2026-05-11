import XCTest
@testable import MacDevCore

final class ListeningServerTests: XCTestCase {
  func testDisplayPortDoesNotUseLocaleGrouping() {
    let server = ListeningServer(
      port: 18789,
      addresses: ["127.0.0.1"],
      processID: 42,
      processName: "openclaw",
      process: nil,
      runtime: .unknown,
      warning: nil
    )

    XCTAssertEqual(server.displayPort, "18789")
  }

  func testRootWorkingDirectoryFallsBackToProcessName() {
    let process = MacDevProcess(
      id: 42,
      parentID: nil,
      user: "johannes",
      command: "/usr/libexec/rapportd",
      currentDirectory: "/"
    )
    let server = ListeningServer(
      port: 7265,
      addresses: ["*"],
      processID: 42,
      processName: "rapportd",
      process: process,
      runtime: .unknown,
      warning: nil
    )

    XCTAssertEqual(server.displayTitle, "rapportd")
    XCTAssertEqual(server.workspaceName, "rapportd")
  }
}

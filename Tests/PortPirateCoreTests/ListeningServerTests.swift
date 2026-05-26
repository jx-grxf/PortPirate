import XCTest
@testable import PortPirateCore

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
    let process = PortPirateProcess(
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

  func testEditorHelperDetectionViaCommandLine() {
    let server = makeServer(
      command: "/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper",
      cwd: "/Users/me"
    )

    XCTAssertTrue(server.isEditorHelper)
    XCTAssertFalse(server.isPrimaryRuntime)
  }

  func testEditorHelperDetectionViaCwd() {
    let server = makeServer(
      command: "node",
      cwd: "/Applications/Cursor.app/Contents/Resources/app/extensions/foo"
    )

    XCTAssertTrue(server.isEditorHelper)
  }

  func testRegularDevServerIsNotEditorHelper() {
    let server = makeServer(
      command: "node /Users/me/project/server.js",
      cwd: "/Users/me/project"
    )

    XCTAssertFalse(server.isEditorHelper)
  }

  private func makeServer(command: String, cwd: String?) -> ListeningServer {
    let process = PortPirateProcess(
      id: 42,
      parentID: nil,
      user: "me",
      command: command,
      currentDirectory: cwd
    )
    return ListeningServer(
      port: 3000,
      addresses: ["127.0.0.1"],
      processID: 42,
      processName: "node",
      process: process,
      runtime: .node,
      warning: nil
    )
  }
}

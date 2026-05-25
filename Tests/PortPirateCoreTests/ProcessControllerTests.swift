import XCTest
@testable import PortPirateCore

final class ProcessControllerTests: XCTestCase {
  func testStoppingMissingProcessCountsAsAlreadyStopped() throws {
    let controller = ProcessController()
    let result = try controller.stop(processID: Int32.max, force: false)

    XCTAssertEqual(result, .alreadyStopped)
  }

  func testScriptEnvironmentPrependsDefaultToolPathsWithoutDroppingExistingPath() {
    let environment = ProcessControllerEnvironment.scriptEnvironment(
      base: [
        "PATH": "/Users/johannes/.volta/bin:/usr/bin:/custom/bin",
        "HOME": "/Users/johannes",
        "OPENAI_API_KEY": "secret",
        "SSH_AUTH_SOCK": "/tmp/agent.sock",
        "LC_CTYPE": "UTF-8"
      ]
    )

    XCTAssertEqual(environment["HOME"], "/Users/johannes")
    XCTAssertEqual(environment["LC_CTYPE"], "UTF-8")
    XCTAssertNil(environment["OPENAI_API_KEY"])
    XCTAssertNil(environment["SSH_AUTH_SOCK"])
    XCTAssertEqual(
      environment["PATH"],
      "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/johannes/.volta/bin:/custom/bin"
    )
  }
}

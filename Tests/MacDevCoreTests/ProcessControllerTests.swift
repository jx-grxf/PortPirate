import XCTest
@testable import MacDevCore

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
        "HOME": "/Users/johannes"
      ]
    )

    XCTAssertEqual(environment["HOME"], "/Users/johannes")
    XCTAssertEqual(
      environment["PATH"],
      "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/johannes/.volta/bin:/custom/bin"
    )
  }
}

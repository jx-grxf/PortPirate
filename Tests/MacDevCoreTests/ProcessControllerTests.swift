import XCTest
@testable import MacDevCore

final class ProcessControllerTests: XCTestCase {
  func testStoppingMissingProcessCountsAsAlreadyStopped() throws {
    let controller = ProcessController()
    let result = try controller.stop(processID: Int32.max, force: false)

    XCTAssertEqual(result, .alreadyStopped)
  }
}

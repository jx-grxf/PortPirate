import XCTest
@testable import PortPirateCore

final class ProcessInspectorTests: XCTestCase {
  func testContextForCurrentProcessIncludesProcessDetails() async {
    let inspector = ProcessInspector()

    let context = await inspector.context(for: getpid())

    XCTAssertEqual(context?.pid, getpid())
    XCTAssertGreaterThanOrEqual(context?.ppidChain.count ?? 0, 2)
    XCTAssertNotNil(context?.cwd)
    XCTAssertFalse(context?.argv.isEmpty ?? true)
  }

  func testParentChainTerminatesAtLaunchdOrRoot() async {
    let inspector = ProcessInspector()

    let chain = await inspector.parentChain(of: getpid())

    XCTAssertFalse(chain.isEmpty)
    XCTAssertTrue(chain.last == 1 || chain.last == 0)
  }
}

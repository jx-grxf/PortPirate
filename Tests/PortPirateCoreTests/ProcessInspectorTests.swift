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

  func testParentChainHasNoCycle() async {
    let inspector = ProcessInspector()

    let chain = await inspector.parentChain(of: getpid())

    XCTAssertGreaterThanOrEqual(chain.count, 2)
    XCTAssertEqual(Set(chain).count, chain.count)
  }
}

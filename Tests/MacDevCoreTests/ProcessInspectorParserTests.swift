import XCTest
@testable import MacDevCore

final class ProcessInspectorParserTests: XCTestCase {
  func testParsesPsRowsWithCommandSpaces() {
    let output = """
      1234     100 johannes node /repo/node_modules/.bin/vite --host 0.0.0.0
        42       1 root /usr/libexec/sharingd
    """

    let processes = ProcessInspectorParser.parsePS(output)

    XCTAssertEqual(processes[1234]?.parentID, 100)
    XCTAssertEqual(processes[1234]?.user, "johannes")
    XCTAssertEqual(processes[1234]?.command, "node /repo/node_modules/.bin/vite --host 0.0.0.0")
    XCTAssertEqual(processes[42]?.user, "root")
  }
}

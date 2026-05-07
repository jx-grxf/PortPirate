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

  func testParsesBatchedCurrentDirectories() {
    let output = """
    p998
    fcwd
    n/Users/johannesgrof/Downloads/calc_troll
    p27798
    fcwd
    n/Users/johannesgrof/tmp/calc
    """

    let directories = ProcessInspectorParser.parseCurrentDirectories(output)

    XCTAssertEqual(directories[998], "/Users/johannesgrof/Downloads/calc_troll")
    XCTAssertEqual(directories[27798], "/Users/johannesgrof/tmp/calc")
  }
}

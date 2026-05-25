import XCTest
@testable import PortPirateCore

final class PortScannerParserTests: XCTestCase {
  func testParsesLsofFieldOutput() {
    let output = """
    p1234
    cnode
    n*:3000
    n[::1]:3000
    p42
    cControlCenter
    n127.0.0.1:5000
    """

    let endpoints = PortScannerParser.parse(output)

    XCTAssertEqual(endpoints.count, 3)
    XCTAssertEqual(endpoints[0].processID, 1234)
    XCTAssertEqual(endpoints[0].processName, "node")
    XCTAssertEqual(endpoints[0].address, "*")
    XCTAssertEqual(endpoints[0].port, 3000)
    XCTAssertEqual(endpoints[1].address, "::1")
    XCTAssertEqual(endpoints[2].processName, "ControlCenter")
    XCTAssertEqual(endpoints[2].port, 5000)
  }

  func testParserResetsCommandWhenNewPidHasNoCommandField() {
    let output = """
    p100
    cnode
    n*:3000
    p200
    n*:8080
    """

    let endpoints = PortScannerParser.parse(output)

    XCTAssertEqual(endpoints.map(\.processName), ["node", "process"])
  }
}

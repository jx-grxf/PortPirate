import XCTest
@testable import PortPirateCore

final class PortPirateProcessTests: XCTestCase {
  func testDecodesOldSnapshotsWithDefaultOwnerFields() throws {
    let data = """
    {
      "id": 123,
      "parentID": 1,
      "user": "johannes",
      "command": "/usr/bin/python3 -m http.server",
      "currentDirectory": "/tmp"
    }
    """.data(using: .utf8)!

    let process = try JSONDecoder().decode(PortPirateProcess.self, from: data)

    XCTAssertEqual(process.owner, .unknown)
    XCTAssertNil(process.gitContext)
    XCTAssertNil(process.startedAt)
  }
}

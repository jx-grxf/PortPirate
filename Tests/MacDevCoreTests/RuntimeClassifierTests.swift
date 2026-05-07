import XCTest
@testable import MacDevCore

final class RuntimeClassifierTests: XCTestCase {
  func testClassifiesCommonDevRuntimes() {
    XCTAssertEqual(
      RuntimeClassifier.classify(processName: "node", command: "node node_modules/.bin/vite", port: 5173, currentDirectory: nil),
      .vite
    )
    XCTAssertEqual(
      RuntimeClassifier.classify(processName: "node", command: "next dev -p 3001", port: 3001, currentDirectory: nil),
      .next
    )
    XCTAssertEqual(
      RuntimeClassifier.classify(processName: "bun", command: "bun run dev", port: 3000, currentDirectory: nil),
      .bun
    )
  }

  func testWarnsAboutAirPlayPorts() {
    let runtime = RuntimeClassifier.classify(
      processName: "ControlCenter",
      command: "/System/Library/CoreServices/ControlCenter.app",
      port: 5000,
      currentDirectory: nil
    )

    XCTAssertEqual(runtime, .airPlay)
    XCTAssertNotNil(RuntimeClassifier.warning(for: runtime, port: 5000, command: "ControlCenter"))
  }
}

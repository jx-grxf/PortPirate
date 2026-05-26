import XCTest
@testable import PortPirateCore

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

  func testUnknownListenerIsNotAStatusWarning() {
    let runtime = RuntimeClassifier.classify(
      processName: "rapportd",
      command: "/usr/libexec/rapportd",
      port: 49152,
      currentDirectory: "/"
    )

    XCTAssertEqual(runtime, .unknown)
    XCTAssertNil(RuntimeClassifier.warning(for: runtime, port: 49152, command: "/usr/libexec/rapportd"))
  }

  func testClassifiesPythonHttpServerAsPrimaryRuntime() {
    let runtime = RuntimeClassifier.classify(
      processName: "Python",
      command: "/opt/homebrew/Cellar/python@3.14/3.14.5/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python -m http.server 4242",
      port: 4242,
      currentDirectory: "/Users/me/repo"
    )

    XCTAssertEqual(runtime, .python)
    XCTAssertTrue(runtime.isPrimaryRuntime)
  }

  func testClassifiesPostgresAsDatabase() {
    let runtime = RuntimeClassifier.classify(
      processName: "postgres",
      command: "/opt/homebrew/opt/postgresql@16/bin/postgres -D /opt/homebrew/var/postgresql@16",
      port: 5432,
      currentDirectory: nil
    )

    XCTAssertEqual(runtime, .database)
    XCTAssertTrue(runtime.isPrimaryRuntime)
    XCTAssertFalse(runtime.usesHTTP)
  }

  func testOpenClawInstalledThroughHomebrewNodeModulesIsNotHomebrewService() {
    let runtime = RuntimeClassifier.classify(
      processName: "node",
      command: "/opt/homebrew/lib/node_modules/openclaw/dist/index.js gateway --port 18789",
      port: 18789,
      currentDirectory: "/Users/johannesgrof/.openclaw"
    )

    XCTAssertEqual(runtime, .openClaw)
  }
}

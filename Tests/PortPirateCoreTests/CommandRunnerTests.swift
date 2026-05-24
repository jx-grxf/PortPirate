import XCTest
@testable import PortPirateCore

final class CommandRunnerTests: XCTestCase {
  func testCommandTimeoutReturnsQuickly() async {
    let runner = ShellCommandRunner(timeout: 0.1)

    do {
      _ = try await runner.run("/bin/sleep", ["2"])
      XCTFail("Expected timeout")
    } catch let error as CommandTimeout {
      XCTAssertEqual(error.executable, "/bin/sleep")
    } catch {
      XCTFail("Expected CommandTimeout, got \(error)")
    }
  }

  func testCommandTimeoutEscalatesWhenProcessIgnoresTerminate() async {
    let runner = ShellCommandRunner(timeout: 0.1)
    let start = Date()

    do {
      _ = try await runner.run("/bin/sh", ["-c", "trap '' TERM; sleep 2"])
      XCTFail("Expected timeout")
    } catch is CommandTimeout {
      XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    } catch {
      XCTFail("Expected CommandTimeout, got \(error)")
    }
  }

  func testCommandRunnerDrainsLargeOutput() async throws {
    let runner = ShellCommandRunner(timeout: 2)

    let output = try await runner.run("/bin/sh", ["-c", "yes PortPirate | head -n 20000"])

    XCTAssertTrue(output.contains("PortPirate"))
  }
}

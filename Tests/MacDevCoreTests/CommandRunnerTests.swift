import XCTest
@testable import MacDevCore

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
}

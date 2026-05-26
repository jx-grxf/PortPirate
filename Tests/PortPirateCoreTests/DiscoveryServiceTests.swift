import XCTest
@testable import PortPirateCore

final class DiscoveryServiceTests: XCTestCase {
  func testDiscoveredChildProcessIncludesOwnerAndStartTime() async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["30"]

    let startedBefore = Date()
    try process.run()
    defer {
      if process.isRunning {
        process.terminate()
        process.waitUntilExit()
      }
    }

    let processID = process.processIdentifier
    let scanner = FakePortScanner(
      endpoints: [
        PortEndpoint(
          processID: processID,
          processName: "sleep",
          address: "127.0.0.1",
          port: 65000
        )
      ]
    )
    let detector = AgentDetector { pid in
      pid == getpid() ? "zsh" : nil
    }
    let service = DiscoveryService(
      portScanner: scanner,
      processInspector: ProcessInspector(),
      agentDetector: detector
    )

    let snapshot = try await service.scan(includeLaunchAgents: false)
    let server = try XCTUnwrap(snapshot.servers.first)
    let discoveredProcess = try XCTUnwrap(server.process)
    let startedAt = try XCTUnwrap(discoveredProcess.startedAt)

    XCTAssertEqual(discoveredProcess.id, processID)
    XCTAssertEqual(discoveredProcess.owner, .manual)
    XCTAssertGreaterThanOrEqual(startedAt.timeIntervalSince(startedBefore), -5)
    XCTAssertLessThanOrEqual(startedAt.timeIntervalSince(Date()), 5)
  }
}

private struct FakePortScanner: PortScanning {
  let endpoints: [PortEndpoint]

  func scan() async throws -> [PortEndpoint] {
    endpoints
  }
}

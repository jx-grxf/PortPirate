import XCTest
@testable import MacDevCore

final class PackageScriptScannerTests: XCTestCase {
  func testScansPackageScriptsAndPackageManager() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try """
    {
      "name": "sample-app",
      "scripts": {
        "dev": "vite --host 0.0.0.0",
        "preview": "vite preview --port 4173"
      }
    }
    """.write(to: directory.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
    FileManager.default.createFile(atPath: directory.appendingPathComponent("pnpm-lock.yaml").path, contents: Data())

    let profile = try PackageScriptScanner.scanWorkspace(at: directory)

    XCTAssertEqual(profile.name, "sample-app")
    XCTAssertEqual(profile.packageManager, .pnpm)
    XCTAssertEqual(profile.scripts.map(\.name), ["dev", "preview"])
    XCTAssertTrue(profile.expectedPorts.contains(5173))
    XCTAssertTrue(profile.expectedPorts.contains(4173))
  }
}

import XCTest
@testable import PortPirateCore

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

  func testDetectsCommonPortSyntaxes() {
    let scripts = [
      PackageScript(name: "next", command: "PORT=3000 next dev"),
      PackageScript(name: "vite", command: "vite --port=5174"),
      PackageScript(name: "serve", command: "astro dev -p4322"),
      PackageScript(name: "broken", command: "vite --port 70000")
    ]

    XCTAssertEqual(PackageScriptScanner.expectedPorts(from: scripts), [3000, 4322, 5174])
  }

  func testSwiftPackageFolderWithoutPackageJsonIsStillAdoptable() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    FileManager.default.createFile(atPath: directory.appendingPathComponent("Package.swift").path, contents: Data())

    let profile = try PackageScriptScanner.scanWorkspace(at: directory)

    XCTAssertEqual(profile.packageManager, .swift)
    XCTAssertEqual(profile.scripts, [])
    XCTAssertEqual(profile.name, directory.lastPathComponent)
  }

  func testPlainFolderWithoutAnyMarkerIsStillAdoptable() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let profile = try PackageScriptScanner.scanWorkspace(at: directory)

    XCTAssertEqual(profile.packageManager, .other)
    XCTAssertEqual(profile.scripts, [])
    XCTAssertEqual(profile.packageManager.runsScripts, false)
  }

  func testMissingFolderThrows() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID())", isDirectory: true)
    XCTAssertThrowsError(try PackageScriptScanner.scanWorkspace(at: directory))
  }
}

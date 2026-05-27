import CryptoKit
import Foundation

public enum PackageManager: String, Codable, CaseIterable, Sendable {
  case npm
  case pnpm
  case yarn
  case bun
  case swift
  case cargo
  case go
  case python
  case ruby
  case other

  public var command: String { rawValue }

  public var label: String {
    switch self {
    case .npm: "npm"
    case .pnpm: "pnpm"
    case .yarn: "yarn"
    case .bun: "bun"
    case .swift: "Swift Package"
    case .cargo: "Cargo"
    case .go: "Go module"
    case .python: "Python"
    case .ruby: "Ruby"
    case .other: "folder"
    }
  }

  public var runsScripts: Bool {
    switch self {
    case .npm, .pnpm, .yarn, .bun: true
    default: false
    }
  }
}

public struct PackageScript: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let name: String
  public let command: String

  public init(name: String, command: String) {
    self.id = name
    self.name = name
    self.command = command
  }
}

public struct WorkspaceProfile: Identifiable, Hashable, Codable, Sendable {
  public let id: UUID
  public var name: String
  public var path: String
  public var packageManager: PackageManager
  public var scripts: [PackageScript]
  public var expectedPorts: [Int]

  public init(
    id: UUID = UUID(),
    name: String,
    path: String,
    packageManager: PackageManager,
    scripts: [PackageScript],
    expectedPorts: [Int] = []
  ) {
    self.id = id
    self.name = name
    self.path = path
    self.packageManager = packageManager
    self.scripts = scripts
    self.expectedPorts = expectedPorts
  }

  public static func stableID(for path: String) -> UUID {
    let digest = SHA256.hash(data: Data(path.utf8))
    let bytes = Array(digest.prefix(16))
    let uuidString = String(
      format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5],
      bytes[6], bytes[7],
      bytes[8], bytes[9],
      bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
    )
    return UUID(uuidString: uuidString) ?? UUID()
  }
}

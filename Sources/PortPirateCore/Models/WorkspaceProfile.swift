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
}

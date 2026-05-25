import Foundation

public enum PackageManager: String, Codable, CaseIterable, Sendable {
  case npm
  case pnpm
  case yarn
  case bun

  public var command: String { rawValue }
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

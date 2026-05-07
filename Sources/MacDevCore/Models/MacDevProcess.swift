import Foundation

public struct MacDevProcess: Identifiable, Hashable, Codable, Sendable {
  public let id: Int32
  public let parentID: Int32?
  public let user: String?
  public let command: String
  public let currentDirectory: String?

  public init(
    id: Int32,
    parentID: Int32?,
    user: String?,
    command: String,
    currentDirectory: String?
  ) {
    self.id = id
    self.parentID = parentID
    self.user = user
    self.command = command
    self.currentDirectory = currentDirectory
  }

  public var displayName: String {
    let parts = command.split(separator: " ")
    guard let first = parts.first else { return "process" }
    return URL(fileURLWithPath: String(first)).lastPathComponent
  }
}

import Foundation

public struct PortPirateProcess: Identifiable, Hashable, Codable, Sendable {
  public let id: Int32
  public let parentID: Int32?
  public let user: String?
  public let command: String
  public let currentDirectory: String?
  public let owner: ProcessOwner
  public let gitContext: GitContext?
  public let startedAt: Date?

  public init(
    id: Int32,
    parentID: Int32?,
    user: String?,
    command: String,
    currentDirectory: String?,
    owner: ProcessOwner = .unknown,
    gitContext: GitContext? = nil,
    startedAt: Date? = nil
  ) {
    self.id = id
    self.parentID = parentID
    self.user = user
    self.command = command
    self.currentDirectory = currentDirectory
    self.owner = owner
    self.gitContext = gitContext
    self.startedAt = startedAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case parentID
    case user
    case command
    case currentDirectory
    case owner
    case gitContext
    case startedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int32.self, forKey: .id)
    self.parentID = try container.decodeIfPresent(Int32.self, forKey: .parentID)
    self.user = try container.decodeIfPresent(String.self, forKey: .user)
    self.command = try container.decode(String.self, forKey: .command)
    self.currentDirectory = try container.decodeIfPresent(String.self, forKey: .currentDirectory)
    self.owner = try container.decodeIfPresent(ProcessOwner.self, forKey: .owner) ?? .unknown
    self.gitContext = try container.decodeIfPresent(GitContext.self, forKey: .gitContext)
    self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
  }

  public var displayName: String {
    let parts = command.split(separator: " ")
    guard let first = parts.first else { return "process" }
    return URL(fileURLWithPath: String(first)).lastPathComponent
  }
}

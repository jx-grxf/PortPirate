import Foundation

public struct RunningScript: Identifiable, Hashable {
  public let id: UUID
  public let profileID: UUID
  public let profileName: String
  public let scriptName: String
  public let processID: Int32
  public var lines: [String]
  public var startedAt: Date

  public init(
    id: UUID = UUID(),
    profileID: UUID,
    profileName: String,
    scriptName: String,
    processID: Int32,
    lines: [String] = [],
    startedAt: Date = Date()
  ) {
    self.id = id
    self.profileID = profileID
    self.profileName = profileName
    self.scriptName = scriptName
    self.processID = processID
    self.lines = lines
    self.startedAt = startedAt
  }
}

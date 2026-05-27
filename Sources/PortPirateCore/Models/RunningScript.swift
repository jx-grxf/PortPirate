import Foundation

public struct RunningScript: Identifiable, Hashable {
  public let id: UUID
  public let profileID: UUID
  public let profileName: String
  public let scriptName: String
  public let processID: Int32
  public let parentProcessID: Int32?
  public var lines: [String]
  public var startedAt: Date
  public var isRunning: Bool
  public var isManaged: Bool

  public init(
    id: UUID = UUID(),
    profileID: UUID,
    profileName: String,
    scriptName: String,
    processID: Int32,
    parentProcessID: Int32? = nil,
    lines: [String] = [],
    startedAt: Date = Date(),
    isRunning: Bool = true,
    isManaged: Bool = true
  ) {
    self.id = id
    self.profileID = profileID
    self.profileName = profileName
    self.scriptName = scriptName
    self.processID = processID
    self.parentProcessID = parentProcessID
    self.lines = lines
    self.startedAt = startedAt
    self.isRunning = isRunning
    self.isManaged = isManaged
  }
}

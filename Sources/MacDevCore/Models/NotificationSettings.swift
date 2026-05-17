import Foundation

public struct NotificationSettings: Codable, Hashable, Sendable {
  public var portCollisionsEnabled: Bool
  public var managedProcessCrashEnabled: Bool
  public var expectedPortMissingEnabled: Bool
  public var scanFailureEnabled: Bool

  public init(
    portCollisionsEnabled: Bool = true,
    managedProcessCrashEnabled: Bool = true,
    expectedPortMissingEnabled: Bool = true,
    scanFailureEnabled: Bool = true
  ) {
    self.portCollisionsEnabled = portCollisionsEnabled
    self.managedProcessCrashEnabled = managedProcessCrashEnabled
    self.expectedPortMissingEnabled = expectedPortMissingEnabled
    self.scanFailureEnabled = scanFailureEnabled
  }
}

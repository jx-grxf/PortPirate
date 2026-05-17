import Foundation
import UserNotifications

public enum MacDevNotificationAuthorization: String, Sendable {
  case notDetermined
  case denied
  case authorized
  case provisional
  case ephemeral
  case unknown

  public var title: String {
    switch self {
    case .notDetermined: "Not requested"
    case .denied: "Denied"
    case .authorized: "Allowed"
    case .provisional: "Provisional"
    case .ephemeral: "Ephemeral"
    case .unknown: "Unknown"
    }
  }
}

public actor NotificationService {
  private let center: UNUserNotificationCenter
  private var lastSent: [String: Date] = [:]
  private let cooldown: TimeInterval

  public init(
    center: UNUserNotificationCenter = .current(),
    cooldown: TimeInterval = 300
  ) {
    self.center = center
    self.cooldown = cooldown
  }

  public func authorizationStatus() async -> MacDevNotificationAuthorization {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined: return .notDetermined
    case .denied: return .denied
    case .authorized: return .authorized
    case .provisional: return .provisional
    case .ephemeral: return .ephemeral
    @unknown default: return .unknown
    }
  }

  @discardableResult
  public func requestAuthorization() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound, .badge])
  }

  public func sendTestNotification() async throws {
    try await send(
      id: "test",
      title: "MacDev notifications are working",
      body: "You will get alerts for collisions, missing expected ports, crashes, and scan failures.",
      bypassCooldown: true
    )
  }

  public func notifyPortCollision(server: ListeningServer) async throws {
    try await send(
      id: "collision-\(server.port)-\(server.processID)",
      title: "Port \(server.port) needs attention",
      body: "\(server.displayTitle) is listening on localhost:\(server.port). Verify it before stopping PID \(server.processID)."
    )
  }

  public func notifyExpectedPortMissing(profile: WorkspaceProfile, port: Int) async throws {
    try await send(
      id: "missing-\(profile.id)-\(port)",
      title: "Expected port \(port) is missing",
      body: "\(profile.name) expects localhost:\(port), but MacDev did not find a listener."
    )
  }

  public func notifyManagedProcessExited(_ script: RunningScript, status: Int32) async throws {
    try await send(
      id: "script-\(script.id)-\(status)",
      title: "\(script.scriptName) exited",
      body: "\(script.profileName) finished with status \(status)."
    )
  }

  public func notifyScanFailure(_ message: String) async throws {
    try await send(
      id: "scan-failure",
      title: "MacDev scan failed",
      body: message
    )
  }

  private func send(id: String, title: String, body: String, bypassCooldown: Bool = false) async throws {
    let status = await authorizationStatus()
    guard status == .authorized || status == .provisional || status == .ephemeral else { return }

    if !bypassCooldown, let previous = lastSent[id], Date().timeIntervalSince(previous) < cooldown {
      return
    }
    lastSent[id] = Date()

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(identifier: "macdev-\(id)", content: content, trigger: nil)
    try await center.add(request)
  }
}

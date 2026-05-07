import Foundation

public struct DiagnosticResult: Identifiable, Hashable, Sendable {
  public let id = UUID()
  public let port: Int
  public let title: String
  public let cause: String
  public let recommendedAction: String
  public let server: ListeningServer?
  public let severity: RuntimeState

  public init(
    port: Int,
    title: String,
    cause: String,
    recommendedAction: String,
    server: ListeningServer?,
    severity: RuntimeState
  ) {
    self.port = port
    self.title = title
    self.cause = cause
    self.recommendedAction = recommendedAction
    self.server = server
    self.severity = severity
  }
}

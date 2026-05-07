import Foundation

public struct ListeningServer: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let port: Int
  public let addresses: [String]
  public let processID: Int32
  public let processName: String
  public let process: MacDevProcess?
  public let runtime: RuntimeKind
  public let warning: String?
  public let detectedAt: Date

  public init(
    port: Int,
    addresses: [String],
    processID: Int32,
    processName: String,
    process: MacDevProcess?,
    runtime: RuntimeKind,
    warning: String?,
    detectedAt: Date = Date()
  ) {
    self.id = "\(processID):\(port)"
    self.port = port
    self.addresses = addresses.sorted()
    self.processID = processID
    self.processName = processName
    self.process = process
    self.runtime = runtime
    self.warning = warning
    self.detectedAt = detectedAt
  }

  public var localhostURL: URL? {
    URL(string: "http://localhost:\(port)")
  }

  public var workspaceName: String {
    guard let currentDirectory = process?.currentDirectory else {
      return "Unknown workspace"
    }
    return URL(fileURLWithPath: currentDirectory).lastPathComponent
  }

  public var commandLine: String {
    process?.command ?? processName
  }

  public var isAppleService: Bool {
    let command = commandLine.lowercased()
    return runtime == .airPlay
      || command.contains("/system/library/")
      || command.contains("/usr/libexec/")
      || processName.lowercased().hasPrefix("com.apple.")
      || processName == "ControlCenter"
  }
}

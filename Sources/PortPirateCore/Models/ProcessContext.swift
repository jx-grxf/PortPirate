import Foundation

public struct ProcessContext: Hashable, Codable, Sendable {
  public let pid: pid_t
  public let ppidChain: [pid_t]
  public let cwd: String?
  public let executablePath: String?
  public let argv: [String]
  public let envSubset: [String: String]
  public let startedAt: Date?

  public init(
    pid: pid_t,
    ppidChain: [pid_t],
    cwd: String?,
    executablePath: String?,
    argv: [String],
    envSubset: [String: String],
    startedAt: Date?
  ) {
    self.pid = pid
    self.ppidChain = ppidChain
    self.cwd = cwd
    self.executablePath = executablePath
    self.argv = argv
    self.envSubset = envSubset
    self.startedAt = startedAt
  }
}

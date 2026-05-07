import Foundation

public protocol CommandRunning: Sendable {
  func run(_ executable: String, _ arguments: [String]) async throws -> String
}

public struct CommandFailure: Error, LocalizedError, Sendable {
  public let executable: String
  public let arguments: [String]
  public let status: Int32
  public let output: String

  public var errorDescription: String? {
    "\(executable) \(arguments.joined(separator: " ")) exited with \(status): \(output)"
  }
}

public struct ShellCommandRunner: CommandRunning {
  public init() {}

  public func run(_ executable: String, _ arguments: [String]) async throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: data, as: UTF8.self)

    guard process.terminationStatus == 0 else {
      throw CommandFailure(
        executable: executable,
        arguments: arguments,
        status: process.terminationStatus,
        output: output
      )
    }

    return output
  }
}

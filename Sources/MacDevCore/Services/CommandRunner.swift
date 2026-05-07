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

public struct CommandTimeout: Error, LocalizedError, Sendable {
  public let executable: String
  public let arguments: [String]
  public let seconds: TimeInterval

  public var errorDescription: String? {
    "\(executable) \(arguments.joined(separator: " ")) timed out after \(Int(seconds))s"
  }
}

public struct ShellCommandRunner: CommandRunning {
  private let timeout: TimeInterval

  public init(timeout: TimeInterval = 4) {
    self.timeout = timeout
  }

  public func run(_ executable: String, _ arguments: [String]) async throws -> String {
    let processBox = ProcessBox()
    return try await withThrowingTaskGroup(of: String.self) { group in
      let timeout = timeout
      group.addTask(priority: .utility) {
        try Self.runBlocking(executable, arguments, processBox: processBox)
      }
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        processBox.terminate()
        throw CommandTimeout(executable: executable, arguments: arguments, seconds: timeout)
      }

      guard let result = try await group.next() else {
        throw CommandTimeout(executable: executable, arguments: arguments, seconds: timeout)
      }
      group.cancelAll()
      return result
    }
  }

  private static func runBlocking(_ executable: String, _ arguments: [String], processBox: ProcessBox) throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    processBox.process = process

    try process.run()
    process.waitUntilExit()
    processBox.process = nil

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

  public static func existingExecutable(preferred: String, fallbacks: [String]) -> String {
    let fileManager = FileManager.default
    if fileManager.isExecutableFile(atPath: preferred) {
      return preferred
    }
    return fallbacks.first { fileManager.isExecutableFile(atPath: $0) } ?? preferred
  }
}

private final class ProcessBox: @unchecked Sendable {
  private let lock = NSLock()
  private var storedProcess: Process?

  var process: Process? {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storedProcess
    }
    set {
      lock.lock()
      storedProcess = newValue
      lock.unlock()
    }
  }

  func terminate() {
    process?.terminate()
  }
}

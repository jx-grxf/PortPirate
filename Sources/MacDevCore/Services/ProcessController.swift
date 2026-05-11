import Darwin
import Foundation

public enum ProcessStopResult: Equatable, Sendable {
  case stopped
  case alreadyStopped
}

public enum ProcessControllerError: Error, LocalizedError {
  case permissionDenied(Int32)
  case failedToStop(Int32, Int32)

  public var errorDescription: String? {
    switch self {
    case .permissionDenied(let pid):
      "macOS denied permission to stop PID \(pid)."
    case .failedToStop(let pid, let code):
      "Could not stop PID \(pid). errno \(code)."
    }
  }
}

public enum ProcessStatus {
  public static func isRunning(_ processID: Int32) -> Bool {
    errno = 0
    return kill(processID, 0) == 0 || errno == EPERM
  }
}

public struct ProcessController {
  public init() {}

  @discardableResult
  public func stop(processID: Int32, force: Bool) throws -> ProcessStopResult {
    let signal = force ? SIGKILL : SIGTERM
    guard kill(processID, signal) == 0 else {
      let code = errno
      if code == ESRCH {
        return .alreadyStopped
      }
      if code == EPERM {
        throw ProcessControllerError.permissionDenied(processID)
      }
      throw ProcessControllerError.failedToStop(processID, code)
    }
    return .stopped
  }
}

public extension ProcessController {
  func startScript(
    profile: WorkspaceProfile,
    script: PackageScript,
    outputHandler: @escaping (String) -> Void,
    terminationHandler: @escaping (Int32) -> Void = { _ in }
  ) throws -> Process {
    let process = Process()
    let pipe = Pipe()
    let workspaceURL = URL(fileURLWithPath: profile.path)

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [profile.packageManager.command, "run", script.name]
    process.currentDirectoryURL = workspaceURL
    process.environment = ProcessControllerEnvironment.scriptEnvironment()
    process.standardOutput = pipe
    process.standardError = pipe
    process.terminationHandler = { process in
      pipe.fileHandleForReading.readabilityHandler = nil
      let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
      if !remainingData.isEmpty {
        outputHandler(String(decoding: remainingData, as: UTF8.self))
      }
      terminationHandler(process.terminationStatus)
    }

    pipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      let text = String(decoding: data, as: UTF8.self)
      outputHandler(text)
    }

    try process.run()
    return process
  }
}

enum ProcessControllerEnvironment {
  private static let defaultToolPaths = [
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin"
  ]

  static func scriptEnvironment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
    var environment = base
    let existingPaths = (base["PATH"] ?? "")
      .split(separator: ":", omittingEmptySubsequences: true)
      .map(String.init)
    let mergedPaths = (defaultToolPaths + existingPaths).reduce(into: [String]()) { result, path in
      if !result.contains(path) {
        result.append(path)
      }
    }
    environment["PATH"] = mergedPaths.joined(separator: ":")
    return environment
  }
}

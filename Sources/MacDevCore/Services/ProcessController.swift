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
    kill(processID, 0) == 0 || errno == EPERM
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
    outputHandler: @escaping (String) -> Void
  ) throws -> Process {
    let process = Process()
    let pipe = Pipe()
    let workspaceURL = URL(fileURLWithPath: profile.path)

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [profile.packageManager.command, "run", script.name]
    process.currentDirectoryURL = workspaceURL
    process.standardOutput = pipe
    process.standardError = pipe

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

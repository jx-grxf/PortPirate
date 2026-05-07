import Darwin
import Foundation

public enum ProcessControllerError: Error, LocalizedError {
  case failedToStop(Int32)

  public var errorDescription: String? {
    switch self {
    case .failedToStop(let pid):
      "Could not stop PID \(pid)."
    }
  }
}

public struct ProcessController {
  public init() {}

  public func stop(processID: Int32, force: Bool) throws {
    let signal = force ? SIGKILL : SIGTERM
    guard kill(processID, signal) == 0 else {
      throw ProcessControllerError.failedToStop(processID)
    }
  }

  public func startScript(
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

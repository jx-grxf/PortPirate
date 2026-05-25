import Foundation

public enum ProcessInspectorParser {
  public static func parsePS(_ output: String) -> [Int32: PortPirateProcess] {
    var processes: [Int32: PortPirateProcess] = [:]

    for line in output.split(whereSeparator: \.isNewline) {
      let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
      guard
        parts.count == 4,
        let pid = Int32(parts[0]),
        let parentID = Int32(parts[1])
      else {
        continue
      }

      let user = String(parts[2])
      let command = String(parts[3])
      processes[pid] = PortPirateProcess(
        id: pid,
        parentID: parentID,
        user: user,
        command: command,
        currentDirectory: nil
      )
    }

    return processes
  }

  public static func parseCurrentDirectories(_ output: String) -> [Int32: String] {
    var directories: [Int32: String] = [:]
    var currentPID: Int32?

    for rawLine in output.split(whereSeparator: \.isNewline) {
      guard let field = rawLine.first else { continue }
      let value = String(rawLine.dropFirst())
      switch field {
      case "p":
        currentPID = Int32(value)
      case "n":
        if let currentPID {
          directories[currentPID] = value
        }
      default:
        continue
      }
    }

    return directories
  }
}

public actor ProcessInspector {
  private let runner: CommandRunning
  private let lsofPath: String

  public init(runner: CommandRunning = ShellCommandRunner(), lsofPath: String? = nil) {
    self.runner = runner
    self.lsofPath = lsofPath ?? ShellCommandRunner.existingExecutable(
      preferred: "/usr/sbin/lsof",
      fallbacks: ["/usr/bin/lsof", "/opt/homebrew/bin/lsof"]
    )
  }

  public func inspect(processIDs: Set<Int32>) async -> [Int32: PortPirateProcess] {
    guard !processIDs.isEmpty else { return [:] }

    let idList = processIDs.sorted().map(String.init).joined(separator: ",")
    let output: String
    do {
      output = try await runner.run("/bin/ps", ["-o", "pid=", "-o", "ppid=", "-o", "user=", "-o", "command=", "-p", idList])
    } catch {
      return [:]
    }

    var processes = ProcessInspectorParser.parsePS(output)
    let currentDirectories = await currentDirectories(for: processIDs)
    for processID in processIDs {
      guard let process = processes[processID] else { continue }
      processes[processID] = PortPirateProcess(
        id: process.id,
        parentID: process.parentID,
        user: process.user,
        command: process.command,
        currentDirectory: currentDirectories[processID]
      )
    }

    return processes
  }

  private func currentDirectories(for processIDs: Set<Int32>) async -> [Int32: String] {
    let idList = processIDs.sorted().map(String.init).joined(separator: ",")
    do {
      let output = try await runner.run(lsofPath, ["-a", "-p", idList, "-d", "cwd", "-Fpn"])
      return ProcessInspectorParser.parseCurrentDirectories(output)
    } catch {
      return [:]
    }
  }
}

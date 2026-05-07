import Foundation

public enum ProcessInspectorParser {
  public static func parsePS(_ output: String) -> [Int32: MacDevProcess] {
    var processes: [Int32: MacDevProcess] = [:]

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
      processes[pid] = MacDevProcess(
        id: pid,
        parentID: parentID,
        user: user,
        command: command,
        currentDirectory: nil
      )
    }

    return processes
  }
}

public actor ProcessInspector {
  private let runner: CommandRunning

  public init(runner: CommandRunning = ShellCommandRunner()) {
    self.runner = runner
  }

  public func inspect(processIDs: Set<Int32>) async -> [Int32: MacDevProcess] {
    guard !processIDs.isEmpty else { return [:] }

    let idList = processIDs.map(String.init).joined(separator: ",")
    let output: String
    do {
      output = try await runner.run("/bin/ps", ["-o", "pid=", "-o", "ppid=", "-o", "user=", "-o", "command=", "-p", idList])
    } catch {
      return [:]
    }

    var processes = ProcessInspectorParser.parsePS(output)
    for processID in processIDs {
      guard let process = processes[processID] else { continue }
      let cwd = await currentDirectory(for: processID)
      processes[processID] = MacDevProcess(
        id: process.id,
        parentID: process.parentID,
        user: process.user,
        command: process.command,
        currentDirectory: cwd
      )
    }

    return processes
  }

  private func currentDirectory(for processID: Int32) async -> String? {
    do {
      let output = try await runner.run("/usr/sbin/lsof", ["-a", "-p", String(processID), "-d", "cwd", "-Fn"])
      return output
        .split(whereSeparator: \.isNewline)
        .first { $0.first == "n" }
        .map { String($0.dropFirst()) }
    } catch {
      return nil
    }
  }
}

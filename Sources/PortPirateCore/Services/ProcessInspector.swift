import Foundation
import Darwin

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

  public func context(for pid: pid_t) -> ProcessContext? {
    guard let bsdInfo = bsdInfo(for: pid) else { return nil }
    let arguments = argumentsAndEnvironment(for: pid)

    return ProcessContext(
      pid: pid,
      ppidChain: parentChain(of: pid),
      cwd: vnodePaths(for: pid).cwd,
      executablePath: executablePath(for: pid),
      argv: arguments.argv,
      envSubset: ProcessInspector.filteredEnvironment(arguments.environment),
      startedAt: bsdInfo.pbi_start_tvsec > 0
        ? Date(timeIntervalSince1970: TimeInterval(bsdInfo.pbi_start_tvsec))
        : nil
    )
  }

  public func parentChain(of pid: pid_t, limit: Int = 32) -> [pid_t] {
    guard pid > 0 else { return [pid] }

    var chain = [pid]
    var current = pid

    for _ in 0..<limit {
      guard let info = bsdInfo(for: current) else { break }
      let parent = pid_t(info.pbi_ppid)
      guard parent > 0, parent != current else { break }

      chain.append(parent)
      if parent == 1 { break }
      current = parent
    }

    return chain
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

  private func bsdInfo(for pid: pid_t) -> proc_bsdinfo? {
    var info = proc_bsdinfo()
    let size = MemoryLayout<proc_bsdinfo>.stride
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: UInt8.self, capacity: size) { buffer in
        proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, buffer, Int32(size))
      }
    }

    return result == Int32(size) ? info : nil
  }

  private func vnodePaths(for pid: pid_t) -> (cwd: String?, root: String?) {
    var info = proc_vnodepathinfo()
    let size = MemoryLayout<proc_vnodepathinfo>.stride
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: UInt8.self, capacity: size) { buffer in
        proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, buffer, Int32(size))
      }
    }

    guard result == Int32(size) else { return (nil, nil) }
    return (
      Self.pathString(from: info.pvi_cdir.vip_path),
      Self.pathString(from: info.pvi_rdir.vip_path)
    )
  }

  private func executablePath(for pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard result > 0 else { return nil }

    let path = String(cString: buffer)
    return path.isEmpty ? nil : path
  }

  private func argumentsAndEnvironment(for pid: pid_t) -> (argv: [String], environment: [String: String]) {
    var argMax = 0
    var argMaxSize = MemoryLayout<Int>.stride
    guard sysctlbyname("kern.argmax", &argMax, &argMaxSize, nil, 0) == 0, argMax > 0 else {
      return ([], [:])
    }

    var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
    var buffer = [UInt8](repeating: 0, count: argMax)
    var size = buffer.count
    let status = buffer.withUnsafeMutableBufferPointer { pointer in
      sysctl(&mib, u_int(mib.count), pointer.baseAddress, &size, nil, 0)
    }
    guard status == 0, size > MemoryLayout<Int32>.stride else { return ([], [:]) }

    let argc = buffer.withUnsafeBytes { rawBuffer in
      rawBuffer.load(as: Int32.self)
    }
    guard argc >= 0 else { return ([], [:]) }

    var offset = MemoryLayout<Int32>.stride
    while offset < size, buffer[offset] != 0 {
      offset += 1
    }
    while offset < size, buffer[offset] == 0 {
      offset += 1
    }

    let values = nullTerminatedStrings(in: buffer, from: offset, size: size)
    let argv = Array(values.prefix(Int(argc)))
    let environment = Dictionary(
      values.dropFirst(Int(argc)).compactMap { value -> (String, String)? in
        guard let separator = value.firstIndex(of: "=") else { return nil }
        return (String(value[..<separator]), String(value[value.index(after: separator)...]))
      },
      uniquingKeysWith: { first, _ in first }
    )

    return (argv, environment)
  }

  private func nullTerminatedStrings(in buffer: [UInt8], from startOffset: Int, size: Int) -> [String] {
    var values: [String] = []
    var offset = startOffset

    while offset < size {
      let start = offset
      while offset < size, buffer[offset] != 0 {
        offset += 1
      }

      if start < offset,
         let value = String(bytes: buffer[start..<offset], encoding: .utf8) {
        values.append(value)
      }

      offset += 1
    }

    return values
  }

  private static func filteredEnvironment(_ environment: [String: String]) -> [String: String] {
    environment.filter { key, _ in
      key.hasPrefix("CLAUDE_")
        || key.hasPrefix("CURSOR_")
        || key.hasPrefix("CODEX_")
        || key.hasPrefix("ANTHROPIC_")
        || key.hasPrefix("OPENAI_")
        || key.hasPrefix("npm_")
        || key.hasPrefix("VSCODE_")
        || key == "TERM_PROGRAM"
    }
  }

  private static func pathString<T>(from path: T) -> String? {
    var path = path
    return withUnsafePointer(to: &path) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { buffer in
        let value = String(cString: buffer)
        return value.isEmpty ? nil : value
      }
    }
  }
}

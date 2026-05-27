import Foundation

public actor WorkspaceProcessScanner {
  private let runner: CommandRunning
  private let lsofPath: String

  public init(runner: CommandRunning = ShellCommandRunner(), lsofPath: String? = nil) {
    self.runner = runner
    self.lsofPath = lsofPath ?? ShellCommandRunner.existingExecutable(
      preferred: "/usr/sbin/lsof",
      fallbacks: ["/usr/bin/lsof", "/opt/homebrew/bin/lsof"]
    )
  }

  public func scan(profiles: [WorkspaceProfile]) async -> [RunningScript] {
    do {
      async let psOutput = runner.run("/bin/ps", ["-axo", "pid=", "-o", "ppid=", "-o", "lstart=", "-o", "command="])
      async let cwdOutput = runner.run(lsofPath, ["-nP", "-a", "-u", NSUserName(), "-d", "cwd", "-Fpcn"])
      let rows = WorkspaceProcessScannerParser.parsePS(try await psOutput)
      let directories = WorkspaceProcessScannerParser.parseCurrentDirectories(try await cwdOutput)
      return match(rows: rows, currentDirectories: directories, profiles: profiles)
    } catch {
      return []
    }
  }

  private func match(
    rows: [WorkspaceProcessScannerParser.ProcessRow],
    currentDirectories: [Int32: String],
    profiles: [WorkspaceProfile]
  ) -> [RunningScript] {
    var scripts: [RunningScript] = []
    let ownPID = Int32(ProcessInfo.processInfo.processIdentifier)

    for row in rows where row.pid != ownPID {
      guard let cwd = currentDirectories[row.pid] else { continue }
      guard let profile = profile(for: cwd, command: row.command, storedProfiles: profiles) else { continue }
      guard let scriptName = inferScriptName(row: row, profile: profile) else { continue }

      scripts.append(
        RunningScript(
          id: UUID(),
          profileID: profile.id,
          profileName: profile.name,
          scriptName: scriptName,
          processID: row.pid,
          parentProcessID: row.parentID,
          lines: ["detected from workspace process"],
          startedAt: row.startedAt ?? Date(),
          isRunning: true,
          isManaged: false
        )
      )
    }

    return deduplicated(scripts)
  }

  private func inferScriptName(
    row: WorkspaceProcessScannerParser.ProcessRow,
    profile: WorkspaceProfile
  ) -> String? {
    guard !isToolHelper(row.command) else { return nil }

    for script in profile.scripts {
      if matchScore(row: row, profile: profile, script: script) != nil {
        return script.name
      }
    }

    return nil
  }

  private func deduplicated(_ scripts: [RunningScript]) -> [RunningScript] {
    var byScript: [String: RunningScript] = [:]
    for script in scripts {
      let key = "\(script.profileID):\(script.scriptName)"
      guard let existing = byScript[key] else {
        byScript[key] = script
        continue
      }
      byScript[key] = preferredScript(existing, script)
    }

    return byScript.values
      .sorted {
        if $0.profileName == $1.profileName { return $0.processID < $1.processID }
        return $0.profileName.localizedCaseInsensitiveCompare($1.profileName) == .orderedAscending
      }
  }

  private func preferredScript(_ left: RunningScript, _ right: RunningScript) -> RunningScript {
    if left.parentProcessID == right.processID { return right }
    if right.parentProcessID == left.processID { return left }
    return left.processID < right.processID ? left : right
  }

  private func matchScore(
    row: WorkspaceProcessScannerParser.ProcessRow,
    profile: WorkspaceProfile,
    script: PackageScript
  ) -> Int? {
    let command = normalized(row.command)
    let scriptCommand = normalized(script.command)
    let packageRun = normalized("\(profile.packageManager.command) run \(script.name)")

    if command.contains(packageRun) { return 100 }
    if command.contains(scriptCommand) { return 90 }
    if let unwrapped = unwrappedProjectNodeCommand(scriptCommand), command.contains(unwrapped) { return 80 }
    if let entrypoint = scriptEntrypoint(scriptCommand), command.contains(entrypoint) { return 70 }
    if command.contains(" \(script.name.lowercased())") && command.contains(profile.packageManager.command) { return 60 }
    return nil
  }

  private func normalized(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  private func unwrappedProjectNodeCommand(_ scriptCommand: String) -> String? {
    let wrapper = "node scripts/run-with-project-node.cjs "
    guard scriptCommand.hasPrefix(wrapper) else { return nil }
    let unwrapped = String(scriptCommand.dropFirst(wrapper.count))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return unwrapped.isEmpty ? nil : unwrapped
  }

  private func scriptEntrypoint(_ scriptCommand: String) -> String? {
    let candidates = scriptCommand
      .split(separator: " ")
      .map(String.init)
      .filter { token in
        token.hasSuffix(".js") || token.hasSuffix(".cjs") || token.hasSuffix(".mjs") || token.hasSuffix(".ts")
      }
    guard let last = candidates.last, !last.contains("run-with-project-node.cjs") else { return nil }
    return last
  }

  private func isToolHelper(_ command: String) -> Bool {
    let command = normalized(command)
    return command.contains("/node_modules/@esbuild/")
      || command.contains(" --service=")
      || command.contains("tsserver.js")
      || command.contains("typingsinstaller.js")
  }

  private func isWorkspaceRuntimeCandidate(_ command: String) -> Bool {
    let command = normalized(command)
    return command.contains("npm run")
      || command.contains("pnpm ")
      || command.contains("yarn ")
      || command.contains("bun ")
      || command.contains("node ")
      || command.contains("/node")
      || command.contains("tsx ")
      || command.contains("/tsx")
      || command.contains("vite")
      || command.contains("next ")
      || command.contains("astro ")
      || command.contains("nuxt ")
  }

  private func profile(for cwd: String, command: String, storedProfiles: [WorkspaceProfile]) -> WorkspaceProfile? {
    if let stored = matchingProfile(for: cwd, profiles: storedProfiles) {
      return stored
    }

    guard isWorkspaceRuntimeCandidate(command) else { return nil }

    return try? PackageScriptScanner.scanNearestWorkspace(
      from: URL(fileURLWithPath: cwd, isDirectory: true)
    )
  }

  private func matchingProfile(for cwd: String, profiles: [WorkspaceProfile]) -> WorkspaceProfile? {
    profiles
      .filter { Self.path(cwd, isInside: $0.path) }
      .max { left, right in
        URL(fileURLWithPath: left.path).standardizedFileURL.path.count
          < URL(fileURLWithPath: right.path).standardizedFileURL.path.count
      }
  }

  private static func path(_ childPath: String, isInside parentPath: String) -> Bool {
    let child = URL(fileURLWithPath: childPath, isDirectory: true).standardizedFileURL.path
    let parent = URL(fileURLWithPath: parentPath, isDirectory: true).standardizedFileURL.path
    return child == parent || child.hasPrefix(parent + "/")
  }
}

public enum WorkspaceProcessScannerParser {
  public struct ProcessRow: Equatable, Sendable {
    public let pid: Int32
    public let parentID: Int32?
    public let startedAt: Date?
    public let command: String
  }

  public static func parsePS(_ output: String) -> [ProcessRow] {
    output.split(whereSeparator: \.isNewline).compactMap { rawLine in
      let line = String(rawLine)
      let parts = line.split(separator: " ", maxSplits: 7, omittingEmptySubsequences: true)
      guard parts.count >= 8,
            let pid = Int32(parts[0]),
            let parentID = Int32(parts[1])
      else {
        return nil
      }

      let dateText = parts[2...6].joined(separator: " ")
      let command = String(parts[7])
      return ProcessRow(
        pid: pid,
        parentID: parentID,
        startedAt: parseStartDate(dateText),
        command: command
      )
    }
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

  private static func parseStartDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
    return formatter.date(from: value)
  }
}

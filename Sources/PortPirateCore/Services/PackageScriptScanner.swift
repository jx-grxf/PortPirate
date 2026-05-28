import Foundation

public enum PackageScriptScannerError: LocalizedError, Equatable {
  case folderUnreachable(String)

  public var errorDescription: String? {
    switch self {
    case .folderUnreachable(let name):
      return "Could not read \(name). Make sure the folder still exists and is readable."
    }
  }
}

public enum PackageScriptScanner {
  public static func scanWorkspace(at url: URL) throws -> WorkspaceProfile {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw PackageScriptScannerError.folderUnreachable(url.lastPathComponent)
    }

    let packageURL = url.appendingPathComponent("package.json")
    if let data = try? Data(contentsOf: packageURL),
       let object = try? JSONSerialization.jsonObject(with: data),
       let root = object as? [String: Any] {
      let rawName = (root["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let scriptsObject = root["scripts"] as? [String: String] ?? [:]
      let scripts = scriptsObject
        .map { PackageScript(name: $0.key, command: $0.value) }
        .sorted { $0.name < $1.name }
      let profileName = (rawName?.isEmpty == false ? rawName ?? url.lastPathComponent : url.lastPathComponent)

      return WorkspaceProfile(
        name: profileName,
        path: url.path,
        packageManager: packageManager(for: url, packageManagerField: root["packageManager"] as? String),
        scripts: scripts,
        expectedPorts: expectedPorts(from: scripts)
      )
    }

    return WorkspaceProfile(
      name: url.lastPathComponent,
      path: url.path,
      packageManager: detectProjectKind(at: url),
      scripts: [],
      expectedPorts: []
    )
  }

  public static func scanNearestWorkspace(from url: URL) throws -> WorkspaceProfile {
    let fileManager = FileManager.default
    var current = url.standardizedFileURL
    let homePath = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path

    while current.path != "/" {
      if fileManager.fileExists(atPath: current.appendingPathComponent("package.json").path) {
        let profile = try scanWorkspace(at: current)
        return WorkspaceProfile(
          id: WorkspaceProfile.stableID(for: profile.path),
          name: profile.name,
          path: profile.path,
          packageManager: profile.packageManager,
          scripts: profile.scripts,
          expectedPorts: profile.expectedPorts
        )
      }
      guard current.path.hasPrefix(homePath) else { break }
      current.deleteLastPathComponent()
    }

    throw PackageScriptScannerError.folderUnreachable(url.lastPathComponent)
  }

  public static func packageManager(for workspaceURL: URL, packageManagerField: String? = nil) -> PackageManager {
    if let declared = packageManager(from: packageManagerField) {
      return declared
    }

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: workspaceURL.appendingPathComponent("bun.lockb").path)
      || fileManager.fileExists(atPath: workspaceURL.appendingPathComponent("bun.lock").path) {
      return .bun
    }
    if fileManager.fileExists(atPath: workspaceURL.appendingPathComponent("pnpm-lock.yaml").path) {
      return .pnpm
    }
    if fileManager.fileExists(atPath: workspaceURL.appendingPathComponent("yarn.lock").path) {
      return .yarn
    }
    return .npm
  }

  private static func packageManager(from value: String?) -> PackageManager? {
    guard let name = value?
      .split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    else {
      return nil
    }

    switch name {
    case "npm": return .npm
    case "pnpm": return .pnpm
    case "yarn": return .yarn
    case "bun": return .bun
    default: return nil
    }
  }

  public static func detectProjectKind(at workspaceURL: URL) -> PackageManager {
    let fileManager = FileManager.default
    let exists: (String) -> Bool = { name in
      fileManager.fileExists(atPath: workspaceURL.appendingPathComponent(name).path)
    }

    if exists("Package.swift") { return .swift }
    if exists("Cargo.toml") { return .cargo }
    if exists("go.mod") { return .go }
    if exists("pyproject.toml") || exists("requirements.txt") || exists("Pipfile") { return .python }
    if exists("Gemfile") { return .ruby }
    return .other
  }

  public static func expectedPorts(from scripts: [PackageScript]) -> [Int] {
    var ports = Set<Int>()

    for script in scripts {
      let command = script.command.lowercased()
      ports.formUnion(explicitPorts(in: command))

      if script.name == "dev" || script.name.contains("dev") {
        if command.contains("vite") { ports.insert(5173) }
        if command.contains("next") || command.contains("nuxt") { ports.insert(3000) }
        if command.contains("astro") { ports.insert(4321) }
      }
    }

    return ports.sorted()
  }

  private static func explicitPorts(in command: String) -> [Int] {
    let pattern = #"(?i)(?:(?:--port|-p)(?:\s+|=)|-p|port\s*=\s*)(\d{2,5})"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(command.startIndex..<command.endIndex, in: command)
    return regex.matches(in: command, range: range).compactMap { match in
      guard let portRange = Range(match.range(at: 1), in: command) else { return nil }
      guard let port = Int(command[portRange]), (1...65535).contains(port) else {
        return nil
      }
      return port
    }
  }
}

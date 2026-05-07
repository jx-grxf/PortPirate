import Foundation

public enum PackageScriptScanner {
  public static func scanWorkspace(at url: URL) throws -> WorkspaceProfile {
    let packageURL = url.appendingPathComponent("package.json")
    let data = try Data(contentsOf: packageURL)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let root = object as? [String: Any] else {
      throw CocoaError(.fileReadCorruptFile)
    }

    let rawName = (root["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let scriptsObject = root["scripts"] as? [String: String] ?? [:]
    let scripts = scriptsObject
      .map { PackageScript(name: $0.key, command: $0.value) }
      .sorted { $0.name < $1.name }

    let profile = WorkspaceProfile(
      name: rawName?.isEmpty == false ? rawName! : url.lastPathComponent,
      path: url.path,
      packageManager: packageManager(for: url),
      scripts: scripts,
      expectedPorts: expectedPorts(from: scripts)
    )

    return profile
  }

  public static func packageManager(for workspaceURL: URL) -> PackageManager {
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
    let pattern = #"(?:(?:--port|-p)\s+|PORT=)(\d{2,5})"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(command.startIndex..<command.endIndex, in: command)
    return regex.matches(in: command, range: range).compactMap { match in
      guard let portRange = Range(match.range(at: 1), in: command) else { return nil }
      return Int(command[portRange])
    }
  }
}

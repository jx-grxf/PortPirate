import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class AppState {
  public var servers: [ListeningServer] = []
  public var launchAgents: [LaunchAgentInfo] = []
  public var profiles: [WorkspaceProfile] = []
  public var runningScripts: [RunningScript] = []
  public var selectedServerID: ListeningServer.ID?
  public var diagnosticResult: DiagnosticResult?
  public var diagnosisPortText = ""
  public var isRefreshing = false
  public var errorMessage: String?

  public var refreshInterval: Double {
    didSet { UserDefaults.standard.set(refreshInterval, forKey: Defaults.refreshInterval) }
  }

  public var includeLaunchAgents: Bool {
    didSet { UserDefaults.standard.set(includeLaunchAgents, forKey: Defaults.includeLaunchAgents) }
  }

  public var showStatusCount: Bool {
    didSet { UserDefaults.standard.set(showStatusCount, forKey: Defaults.showStatusCount) }
  }

  public var confirmForceKill: Bool {
    didSet { UserDefaults.standard.set(confirmForceKill, forKey: Defaults.confirmForceKill) }
  }

  private let discoveryService: DiscoveryService
  private let profileStore: ProfileStore
  private let processController = ProcessController()
  private var refreshTask: Task<Void, Never>?
  private var startedProcesses: [UUID: Process] = [:]

  public init(
    discoveryService: DiscoveryService = DiscoveryService(),
    profileStore: ProfileStore = ProfileStore()
  ) {
    self.discoveryService = discoveryService
    self.profileStore = profileStore
    self.refreshInterval = UserDefaults.standard.object(forKey: Defaults.refreshInterval) as? Double ?? 8
    self.includeLaunchAgents = UserDefaults.standard.object(forKey: Defaults.includeLaunchAgents) as? Bool ?? true
    self.showStatusCount = UserDefaults.standard.object(forKey: Defaults.showStatusCount) as? Bool ?? true
    self.confirmForceKill = UserDefaults.standard.object(forKey: Defaults.confirmForceKill) as? Bool ?? true
  }

  public var status: RuntimeState {
    if servers.isEmpty { return .idle }
    if servers.contains(where: { $0.warning != nil }) { return .warning }
    return .ok
  }

  public var selectedServer: ListeningServer? {
    guard let selectedServerID else { return servers.first }
    return servers.first { $0.id == selectedServerID }
  }

  public var warningCount: Int {
    servers.filter { $0.warning != nil }.count
  }

  public func startAutoRefresh() {
    guard refreshTask == nil else { return }
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        await self?.refresh()
        let seconds = max(self?.refreshInterval ?? 8, 2)
        try? await Task.sleep(for: .seconds(seconds))
      }
    }
  }

  public func refresh() async {
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let snapshot = try await discoveryService.scan(includeLaunchAgents: includeLaunchAgents)
      servers = snapshot.servers
      launchAgents = snapshot.launchAgents
      if selectedServerID == nil || !servers.contains(where: { $0.id == selectedServerID }) {
        selectedServerID = servers.first?.id
      }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func loadProfiles() async {
    profiles = await profileStore.load()
  }

  public func addWorkspace(url: URL) {
    do {
      let profile = try PackageScriptScanner.scanWorkspace(at: url)
      profiles.removeAll { $0.path == profile.path }
      profiles.append(profile)
      profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      Task { await profileStore.save(profiles) }
    } catch {
      errorMessage = "Could not read package.json in \(url.lastPathComponent)."
    }
  }

  public func removeProfile(_ profile: WorkspaceProfile) {
    profiles.removeAll { $0.id == profile.id }
    Task { await profileStore.save(profiles) }
  }

  public func diagnose(server: ListeningServer) {
    diagnosisPortText = String(server.port)
    diagnosticResult = DiagnosticService.diagnose(port: server.port, servers: servers)
  }

  public func diagnosePortText() {
    guard let port = Int(diagnosisPortText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      errorMessage = "Enter a valid port number."
      return
    }
    diagnosticResult = DiagnosticService.diagnose(port: port, servers: servers)
  }

  public func open(server: ListeningServer) {
    guard let url = server.localhostURL else { return }
    NSWorkspace.shared.open(url)
  }

  public func stop(server: ListeningServer, force: Bool) async {
    do {
      try processController.stop(processID: server.processID, force: force)
      try? await Task.sleep(for: .milliseconds(350))
      await refresh()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func startScript(_ script: PackageScript, in profile: WorkspaceProfile) {
    let runningID = UUID()
    do {
      let process = try processController.startScript(profile: profile, script: script) { [weak self] output in
        Task { @MainActor in
          self?.appendLog(output, to: runningID)
        }
      }
      startedProcesses[runningID] = process
      runningScripts.append(
        RunningScript(
          id: runningID,
          profileID: profile.id,
          profileName: profile.name,
          scriptName: script.name,
          processID: process.processIdentifier
        )
      )
      Task { await refresh() }
    } catch {
      errorMessage = "Could not start \(script.name): \(error.localizedDescription)"
    }
  }

  public func stopRunningScript(_ script: RunningScript) {
    if let process = startedProcesses[script.id], process.isRunning {
      process.terminate()
    } else {
      try? processController.stop(processID: script.processID, force: false)
    }
    startedProcesses.removeValue(forKey: script.id)
    runningScripts.removeAll { $0.id == script.id }
  }

  private func appendLog(_ output: String, to runningID: UUID) {
    guard let index = runningScripts.firstIndex(where: { $0.id == runningID }) else { return }
    let newLines = output
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter { !$0.isEmpty }

    runningScripts[index].lines.append(contentsOf: newLines)
    if runningScripts[index].lines.count > 300 {
      runningScripts[index].lines.removeFirst(runningScripts[index].lines.count - 300)
    }
  }
}

private enum Defaults {
  static let refreshInterval = "refreshInterval"
  static let includeLaunchAgents = "includeLaunchAgents"
  static let showStatusCount = "showStatusCount"
  static let confirmForceKill = "confirmForceKill"
}

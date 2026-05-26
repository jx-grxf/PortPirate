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
  public var filterAIAgentsOnly = false
  public var filterStaleOnly = false
  public static let staleThreshold: TimeInterval = 30 * 60
  public var notificationAuthorization: PortPirateNotificationAuthorization = .unknown

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

  public var showAppleServices: Bool {
    didSet {
      UserDefaults.standard.set(showAppleServices, forKey: Defaults.showAppleServices)
      if !visibleServers.contains(where: { $0.id == selectedServerID }) {
        selectedServerID = visibleServers.first?.id
      }
    }
  }

  public var notificationSettings: NotificationSettings {
    didSet {
      if let data = try? JSONEncoder().encode(notificationSettings) {
        UserDefaults.standard.set(data, forKey: Defaults.notificationSettings)
      }
    }
  }

  public var updateChannel: UpdateChannel {
    didSet { UserDefaults.standard.set(updateChannel.rawValue, forKey: Defaults.updateChannel) }
  }

  public var automaticallyChecksForUpdates: Bool {
    didSet {
      UserDefaults.standard.set(automaticallyChecksForUpdates, forKey: Defaults.automaticallyChecksForUpdates)
      updateService?.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }
  }

  private let discoveryService: DiscoveryService
  private let profileStore: ProfileStore
  private let notificationService: NotificationService
  private var updateService: UpdateService?
  private let processController = ProcessController()
  private var refreshTask: Task<Void, Never>?
  private var startedProcesses: [UUID: Process] = [:]
  private var notifiedWarningIDs = Set<String>()
  private var notifiedMissingPortIDs = Set<String>()
  private var hasBootstrapped = false

  public init(
    discoveryService: DiscoveryService = DiscoveryService(),
    profileStore: ProfileStore = ProfileStore(),
    notificationService: NotificationService = NotificationService()
  ) {
    self.discoveryService = discoveryService
    self.profileStore = profileStore
    self.notificationService = notificationService
    self.refreshInterval = UserDefaults.standard.object(forKey: Defaults.refreshInterval) as? Double ?? 8
    self.includeLaunchAgents = UserDefaults.standard.object(forKey: Defaults.includeLaunchAgents) as? Bool ?? true
    self.showStatusCount = UserDefaults.standard.object(forKey: Defaults.showStatusCount) as? Bool ?? true
    self.confirmForceKill = UserDefaults.standard.object(forKey: Defaults.confirmForceKill) as? Bool ?? true
    self.showAppleServices = UserDefaults.standard.object(forKey: Defaults.showAppleServices) as? Bool ?? false
    self.updateChannel = UpdateChannel(
      rawValue: UserDefaults.standard.string(forKey: Defaults.updateChannel) ?? ""
    ) ?? .stable
    self.automaticallyChecksForUpdates = UserDefaults.standard.object(
      forKey: Defaults.automaticallyChecksForUpdates
    ) as? Bool ?? true
    if let data = UserDefaults.standard.data(forKey: Defaults.notificationSettings),
       let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
      self.notificationSettings = settings
    } else {
      self.notificationSettings = NotificationSettings()
    }
  }

  public var status: RuntimeState {
    if visibleServers.isEmpty { return .idle }
    if visibleServers.contains(where: { $0.warning != nil }) { return .warning }
    return .ok
  }

  public var selectedServer: ListeningServer? {
    guard let selectedServerID else { return visibleServers.first }
    return visibleServers.first { $0.id == selectedServerID } ?? visibleServers.first
  }

  public var warningCount: Int {
    return visibleServers.filter { $0.warning != nil }.count
  }

  public var visibleServers: [ListeningServer] {
    developerServers + backgroundServers + (showAppleServices ? appleServiceServers : [])
  }

  public var developerServers: [ListeningServer] {
    servers.filter(\.isPrimaryRuntime)
  }

  public var visibleDeveloperServers: [ListeningServer] {
    developerServers.filter(passesActiveFilters)
  }

  public var groupedDeveloperServers: StackGrouper.GroupedServers {
    StackGrouper.group(visibleDeveloperServers)
  }

  public var developerStacks: [WorkspaceStack] {
    groupedDeveloperServers.stacks
  }

  public var ungroupedDeveloperServers: [ListeningServer] {
    groupedDeveloperServers.ungrouped
  }

  public func stopStack(_ stack: WorkspaceStack) async {
    for server in stack.servers where server.isPrimaryRuntime {
      await stop(server: server, force: false)
    }
  }

  public var hasAgentDetectedServers: Bool {
    developerServers.contains { AppState.isAIAgent($0) }
  }

  public var hasStaleServers: Bool {
    developerServers.contains { AppState.isStale($0) }
  }

  public var hasActiveFilter: Bool {
    filterAIAgentsOnly || filterStaleOnly
  }

  private func passesActiveFilters(_ server: ListeningServer) -> Bool {
    if filterAIAgentsOnly, !AppState.isAIAgent(server) { return false }
    if filterStaleOnly, !AppState.isStale(server) { return false }
    return true
  }

  public nonisolated static func isAIAgent(_ server: ListeningServer) -> Bool {
    if case .aiAgent = server.process?.owner { return true }
    return false
  }

  public nonisolated static func isStale(_ server: ListeningServer, now: Date = Date()) -> Bool {
    guard let startedAt = server.process?.startedAt else { return false }
    return now.timeIntervalSince(startedAt) >= staleThreshold
  }

  public var backgroundServers: [ListeningServer] {
    servers.filter { !$0.isAppleService && !$0.isEditorHelper && !$0.isPrimaryRuntime }
  }

  public var editorHelperServers: [ListeningServer] {
    servers.filter(\.isEditorHelper)
  }

  public var appleServiceServers: [ListeningServer] {
    servers.filter(\.isAppleService)
  }

  public func startAutoRefresh() {
    startAutoRefresh(immediately: true)
  }

  public func bootstrap() async {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    startUpdaterIfNeeded()
    await refreshNotificationAuthorization()
    await loadProfiles()
    await refresh()
    startAutoRefresh(immediately: false)
  }

  private func startAutoRefresh(immediately: Bool) {
    guard refreshTask == nil else { return }
    refreshTask = Task { [weak self] in
      var shouldRefresh = immediately
      while !Task.isCancelled {
        if shouldRefresh {
          await self?.refresh()
        }
        shouldRefresh = true
        let seconds = max(self?.refreshInterval ?? 8, 2)
        try? await Task.sleep(for: .seconds(seconds))
      }
    }
  }

  public func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      let snapshot = try await discoveryService.scan(includeLaunchAgents: includeLaunchAgents)
      servers = snapshot.servers
      launchAgents = snapshot.launchAgents
      if selectedServerID == nil || !visibleServers.contains(where: { $0.id == selectedServerID }) {
        selectedServerID = visibleServers.first?.id
      }
      errorMessage = nil
      await sendStateNotifications()
    } catch {
      errorMessage = error.localizedDescription
      if notificationSettings.scanFailureEnabled {
        try? await notificationService.notifyScanFailure(error.localizedDescription)
      }
    }
  }

  public func refreshNotificationAuthorization() async {
    notificationAuthorization = await notificationService.authorizationStatus()
  }

  public func requestNotifications() async {
    do {
      _ = try await notificationService.requestAuthorization()
      await refreshNotificationAuthorization()
    } catch {
      errorMessage = "Could not request notifications: \(error.localizedDescription)"
    }
  }

  public func sendTestNotification() async {
    do {
      try await notificationService.sendTestNotification()
      await refreshNotificationAuthorization()
    } catch {
      errorMessage = "Could not send test notification: \(error.localizedDescription)"
    }
  }

  public var updatesConfigured: Bool {
    UpdateService.isConfigured
  }

  public func checkForUpdates() {
    startUpdaterIfNeeded()
    updateService?.checkForUpdates()
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
    guard
      let port = Int(diagnosisPortText.trimmingCharacters(in: .whitespacesAndNewlines)),
      (1...65535).contains(port)
    else {
      errorMessage = "Enter a valid port from 1 to 65535."
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
      let currentServer = try await validatedStopTarget(for: server)
      let result = try processController.stop(processID: server.processID, force: force)
      try? await Task.sleep(for: .milliseconds(350))
      await refresh()
      if result == .alreadyStopped {
        errorMessage = nil
      } else if ProcessStatus.isRunning(currentServer.processID) {
        errorMessage = force
          ? "PID \(server.processID) is still running after Force Kill."
          : "PID \(server.processID) did not exit. Use Force Kill from the row menu."
      }
    } catch {
      errorMessage = error.localizedDescription
      await refresh()
    }
  }

  private func validatedStopTarget(for server: ListeningServer) async throws -> ListeningServer {
    guard server.isPrimaryRuntime else {
      throw ProcessControllerError.unsafeProcess(server.processID, "only local developer runtimes can be stopped")
    }

    if let user = server.process?.user, user != NSUserName() {
      throw ProcessControllerError.unsafeProcess(server.processID, "process is owned by \(user)")
    }

    let snapshot = try await discoveryService.scan(includeLaunchAgents: false)
    guard let currentServer = snapshot.servers.first(where: {
      $0.processID == server.processID && $0.port == server.port
    }) else {
      throw ProcessControllerError.unsafeProcess(server.processID, "the process is no longer listening on port \(server.port)")
    }

    guard currentServer.isPrimaryRuntime else {
      throw ProcessControllerError.unsafeProcess(server.processID, "the current listener is not a developer runtime")
    }

    if let originalCommand = server.process?.command,
       let currentCommand = currentServer.process?.command,
       originalCommand != currentCommand {
      throw ProcessControllerError.unsafeProcess(server.processID, "process command changed since the last scan")
    }

    if let originalDirectory = server.process?.currentDirectory,
       let currentDirectory = currentServer.process?.currentDirectory,
       originalDirectory != currentDirectory {
      throw ProcessControllerError.unsafeProcess(server.processID, "working directory changed since the last scan")
    }

    return currentServer
  }

  public func startScript(_ script: PackageScript, in profile: WorkspaceProfile) {
    let runningID = UUID()
    do {
      let process = try processController.startScript(
        profile: profile,
        script: script,
        outputHandler: { [weak self] output in
          Task { @MainActor in
            self?.appendLog(output, to: runningID)
          }
        },
        terminationHandler: { [weak self] status in
          Task { @MainActor in
            self?.markScriptFinished(runningID, status: status)
          }
        }
      )
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
      _ = try? processController.stop(processID: script.processID, force: false)
    }
    startedProcesses.removeValue(forKey: script.id)
    markScriptFinished(script.id, status: 0)
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

  private func markScriptFinished(_ runningID: UUID, status: Int32) {
    startedProcesses.removeValue(forKey: runningID)
    guard let index = runningScripts.firstIndex(where: { $0.id == runningID }) else { return }
    guard runningScripts[index].isRunning else { return }
    runningScripts[index].isRunning = false
    appendLog("Exited with status \(status)", to: runningID)
    if status != 0, notificationSettings.managedProcessCrashEnabled {
      let script = runningScripts[index]
      Task {
        try? await notificationService.notifyManagedProcessExited(script, status: status)
      }
    }
  }

  private func sendStateNotifications() async {
    if notificationSettings.portCollisionsEnabled {
      for server in visibleServers where server.warning != nil {
        let id = "\(server.processID):\(server.port):\(server.warning ?? "")"
        guard notifiedWarningIDs.insert(id).inserted else { continue }
        try? await notificationService.notifyPortCollision(server: server)
      }
    }

    if notificationSettings.expectedPortMissingEnabled {
      let activePorts = Set(visibleServers.map(\.port))
      for profile in profiles {
        for port in profile.expectedPorts where !activePorts.contains(port) {
          let id = "\(profile.id):\(port)"
          guard notifiedMissingPortIDs.insert(id).inserted else { continue }
          try? await notificationService.notifyExpectedPortMissing(profile: profile, port: port)
        }
      }
    }
  }

  private func startUpdaterIfNeeded() {
    guard updateService == nil else { return }
    updateService = UpdateService { [weak self] in
      self?.updateChannel ?? .stable
    }
    updateService?.automaticallyChecksForUpdates = automaticallyChecksForUpdates
  }
}

private enum Defaults {
  static let refreshInterval = "refreshInterval"
  static let includeLaunchAgents = "includeLaunchAgents"
  static let showStatusCount = "showStatusCount"
  static let confirmForceKill = "confirmForceKill"
  static let showAppleServices = "showAppleServices"
  static let notificationSettings = "notificationSettings"
  static let updateChannel = "updateChannel"
  static let automaticallyChecksForUpdates = "automaticallyChecksForUpdates"
}

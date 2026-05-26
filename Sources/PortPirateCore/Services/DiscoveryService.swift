import Foundation

public struct DiscoverySnapshot: Sendable {
  public let servers: [ListeningServer]
  public let launchAgents: [LaunchAgentInfo]

  public init(servers: [ListeningServer], launchAgents: [LaunchAgentInfo]) {
    self.servers = servers
    self.launchAgents = launchAgents
  }
}

public actor DiscoveryService {
  private let portScanner: any PortScanning
  private let processInspector: any ProcessInspecting
  private let launchdInspector: LaunchdInspector
  private let agentDetector: AgentDetector
  private let gitContextResolver: GitContextResolver
  private var detectionCache: [pid_t: ProcessDetection] = [:]

  public init(
    portScanner: any PortScanning = PortScanner(),
    processInspector: any ProcessInspecting = ProcessInspector(),
    launchdInspector: LaunchdInspector = LaunchdInspector(),
    agentDetector: AgentDetector = AgentDetector(),
    gitContextResolver: GitContextResolver = GitContextResolver()
  ) {
    self.portScanner = portScanner
    self.processInspector = processInspector
    self.launchdInspector = launchdInspector
    self.agentDetector = agentDetector
    self.gitContextResolver = gitContextResolver
  }

  public func scan(includeLaunchAgents: Bool) async throws -> DiscoverySnapshot {
    let endpoints = try await portScanner.scan()
    let processIDs = Set(endpoints.map(\.processID))
    detectionCache = detectionCache.filter { processIDs.contains($0.key) }
    let processes = await enrichedProcesses(for: processIDs)

    let grouped = Dictionary(grouping: endpoints) { "\($0.processID):\($0.port)" }
    let servers = grouped.values.map { group -> ListeningServer in
      let first = group[0]
      let process = processes[first.processID]
      let command = process?.command ?? first.processName
      let runtime = RuntimeClassifier.classify(
        processName: first.processName,
        command: command,
        port: first.port,
        currentDirectory: process?.currentDirectory
      )
      let warning = RuntimeClassifier.warning(for: runtime, port: first.port, command: command)

      return ListeningServer(
        port: first.port,
        addresses: Array(Set(group.map(\.address))),
        processID: first.processID,
        processName: first.processName,
        process: process,
        runtime: runtime,
        warning: warning
      )
    }
    .sorted {
      if $0.port == $1.port { return $0.processID < $1.processID }
      return $0.port < $1.port
    }

    let launchAgents = includeLaunchAgents ? await launchdInspector.userAgents() : []
    return DiscoverySnapshot(servers: servers, launchAgents: launchAgents)
  }

  private func enrichedProcesses(for processIDs: Set<Int32>) async -> [Int32: PortPirateProcess] {
    let inspected = await processInspector.inspect(processIDs: processIDs)
    var enriched: [Int32: PortPirateProcess] = [:]

    for (processID, process) in inspected {
      let detection = await detection(for: processID)
      enriched[processID] = PortPirateProcess(
        id: process.id,
        parentID: process.parentID,
        user: process.user,
        command: process.command,
        currentDirectory: process.currentDirectory,
        owner: detection.owner,
        gitContext: detection.gitContext,
        startedAt: detection.startedAt
      )
    }

    return enriched
  }

  private func detection(for processID: pid_t) async -> ProcessDetection {
    if let cached = detectionCache[processID] {
      return cached
    }

    guard let context = await processInspector.context(for: processID) else {
      let detection = ProcessDetection(owner: .unknown, gitContext: nil, startedAt: nil)
      detectionCache[processID] = detection
      return detection
    }

    let cwdURL = context.cwd.map { URL(fileURLWithPath: $0, isDirectory: true) }
    let detection = ProcessDetection(
      owner: agentDetector.classify(context),
      gitContext: cwdURL.flatMap(gitContextResolver.resolve),
      startedAt: context.startedAt
    )
    detectionCache[processID] = detection
    return detection
  }

  private struct ProcessDetection: Sendable {
    let owner: ProcessOwner
    let gitContext: GitContext?
    let startedAt: Date?
  }
}

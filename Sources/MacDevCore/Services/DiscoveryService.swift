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
  private let portScanner: PortScanner
  private let processInspector: ProcessInspector
  private let launchdInspector: LaunchdInspector

  public init(
    portScanner: PortScanner = PortScanner(),
    processInspector: ProcessInspector = ProcessInspector(),
    launchdInspector: LaunchdInspector = LaunchdInspector()
  ) {
    self.portScanner = portScanner
    self.processInspector = processInspector
    self.launchdInspector = launchdInspector
  }

  public func scan(includeLaunchAgents: Bool) async throws -> DiscoverySnapshot {
    let endpoints = try await portScanner.scan()
    let processIDs = Set(endpoints.map(\.processID))
    let processes = await processInspector.inspect(processIDs: processIDs)

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
}

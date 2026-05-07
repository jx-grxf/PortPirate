import Foundation

public struct PortEndpoint: Hashable, Sendable {
  public let processID: Int32
  public let processName: String
  public let address: String
  public let port: Int
}

public enum PortScannerParser {
  public static func parse(_ output: String) -> [PortEndpoint] {
    var endpoints: [PortEndpoint] = []
    var currentPID: Int32?
    var currentCommand = "process"

    for rawLine in output.split(whereSeparator: \.isNewline) {
      guard let field = rawLine.first else { continue }
      let value = String(rawLine.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)

      switch field {
      case "p":
        currentPID = Int32(value)
      case "c":
        currentCommand = value.isEmpty ? "process" : value
      case "n":
        guard let currentPID, let parsed = parseAddress(value) else { continue }
        endpoints.append(
          PortEndpoint(
            processID: currentPID,
            processName: currentCommand,
            address: parsed.address,
            port: parsed.port
          )
        )
      default:
        continue
      }
    }

    return endpoints
  }

  private static func parseAddress(_ name: String) -> (address: String, port: Int)? {
    let cleaned = name
      .replacingOccurrences(of: " (LISTEN)", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let separator = cleaned.lastIndex(of: ":") else { return nil }
    let portText = cleaned[cleaned.index(after: separator)...]
      .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
    guard let port = Int(portText) else { return nil }

    let addressText = cleaned[..<separator]
      .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
    let address = addressText.isEmpty ? "*" : String(addressText)
    return (address, port)
  }
}

public actor PortScanner {
  private let runner: CommandRunning

  public init(runner: CommandRunning = ShellCommandRunner()) {
    self.runner = runner
  }

  public func scan() async throws -> [PortEndpoint] {
    do {
      let output = try await runner.run(
        "/usr/sbin/lsof",
        ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
      )
      return PortScannerParser.parse(output)
    } catch let failure as CommandFailure where failure.status == 1 {
      return []
    }
  }
}

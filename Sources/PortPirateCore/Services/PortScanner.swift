import Foundation

public struct PortEndpoint: Hashable, Sendable {
  public let processID: Int32
  public let processName: String
  public let address: String
  public let port: Int
}

public protocol PortScanning: Sendable {
  func scan() async throws -> [PortEndpoint]
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
        currentCommand = "process"
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
  private let lsofPath: String

  public init(runner: CommandRunning = ShellCommandRunner(), lsofPath: String? = nil) {
    self.runner = runner
    self.lsofPath = lsofPath ?? ShellCommandRunner.existingExecutable(
      preferred: "/usr/sbin/lsof",
      fallbacks: ["/usr/bin/lsof", "/opt/homebrew/bin/lsof"]
    )
  }

  public func scan() async throws -> [PortEndpoint] {
    do {
      let output = try await runner.run(
        lsofPath,
        ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
      )
      return PortScannerParser.parse(output)
    } catch let failure as CommandFailure where failure.status == 1 {
      return []
    }
  }
}

extension PortScanner: PortScanning {}

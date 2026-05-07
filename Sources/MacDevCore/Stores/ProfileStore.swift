import Foundation

public actor ProfileStore {
  private let fileURL: URL

  public init(fileManager: FileManager = .default) {
    let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let directory = baseURL.appendingPathComponent("MacDev", isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    self.fileURL = directory.appendingPathComponent("profiles.json")
  }

  public func load() -> [WorkspaceProfile] {
    guard let data = try? Data(contentsOf: fileURL) else { return [] }
    return (try? JSONDecoder().decode([WorkspaceProfile].self, from: data)) ?? []
  }

  public func save(_ profiles: [WorkspaceProfile]) {
    guard let data = try? JSONEncoder.pretty.encode(profiles) else { return }
    try? data.write(to: fileURL, options: [.atomic])
  }
}

private extension JSONEncoder {
  static var pretty: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}

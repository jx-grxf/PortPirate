import Foundation

public enum RuntimeKind: String, Codable, CaseIterable, Sendable {
  case npm
  case pnpm
  case yarn
  case bun
  case vite
  case next
  case astro
  case nuxt
  case docker
  case brew
  case openClaw
  case airPlay
  case launchd
  case node
  case python
  case ruby
  case go
  case rust
  case java
  case dotnet
  case database
  case unknown

  public var title: String {
    switch self {
    case .npm: "npm"
    case .pnpm: "pnpm"
    case .yarn: "Yarn"
    case .bun: "Bun"
    case .vite: "Vite"
    case .next: "Next.js"
    case .astro: "Astro"
    case .nuxt: "Nuxt"
    case .docker: "Docker"
    case .brew: "Homebrew"
    case .openClaw: "OpenClaw"
    case .airPlay: "AirPlay"
    case .launchd: "launchd"
    case .node: "Node"
    case .python: "Python"
    case .ruby: "Ruby"
    case .go: "Go"
    case .rust: "Rust"
    case .java: "Java"
    case .dotnet: ".NET"
    case .database: "Database"
    case .unknown: "Unknown"
    }
  }

  public var systemImage: String {
    switch self {
    case .npm, .pnpm, .yarn, .bun, .node: "terminal"
    case .vite: "bolt"
    case .next: "chevron.left.forwardslash.chevron.right"
    case .astro, .nuxt: "sparkles"
    case .docker: "shippingbox"
    case .brew: "mug"
    case .openClaw: "point.3.connected.trianglepath.dotted"
    case .airPlay: "airplayvideo"
    case .launchd: "gearshape.2"
    case .python, .ruby, .go, .rust, .java, .dotnet: "chevron.left.forwardslash.chevron.right"
    case .database: "cylinder.split.1x2"
    case .unknown: "questionmark.circle"
    }
  }

  public var isPrimaryRuntime: Bool {
    switch self {
    case .npm, .pnpm, .yarn, .bun, .vite, .next, .astro, .nuxt,
         .docker, .brew, .openClaw, .node,
         .python, .ruby, .go, .rust, .java, .dotnet, .database:
      true
    case .airPlay, .launchd, .unknown:
      false
    }
  }

  public var usesHTTP: Bool {
    switch self {
    case .database: false
    default: true
    }
  }
}

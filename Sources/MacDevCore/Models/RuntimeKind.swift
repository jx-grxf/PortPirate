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
  case airPlay
  case launchd
  case node
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
    case .airPlay: "AirPlay"
    case .launchd: "launchd"
    case .node: "Node"
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
    case .airPlay: "airplayvideo"
    case .launchd: "gearshape.2"
    case .unknown: "questionmark.circle"
    }
  }
}

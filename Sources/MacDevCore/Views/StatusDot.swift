import SwiftUI

public struct StatusDot: View {
  private let state: RuntimeState

  public init(_ state: RuntimeState) {
    self.state = state
  }

  public var body: some View {
    Circle()
      .fill(color)
      .frame(width: 8, height: 8)
      .accessibilityLabel(state.title)
  }

  private var color: Color {
    switch state {
    case .idle: .secondary
    case .ok: .green
    case .warning: .yellow
    case .problem: .red
    }
  }
}

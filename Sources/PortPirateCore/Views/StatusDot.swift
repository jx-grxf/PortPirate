import SwiftUI

public struct StatusDot: View {
  private let state: RuntimeState

  public init(_ state: RuntimeState) {
    self.state = state
  }

  public var body: some View {
    Image(systemName: symbolName)
      .font(.system(size: 10, weight: .bold))
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(color)
      .frame(width: 12, height: 12)
      .accessibilityLabel(state.title)
  }

  private var symbolName: String {
    switch state {
    case .idle: "circle.fill"
    case .ok: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .problem: "xmark.octagon.fill"
    }
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

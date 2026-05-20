import SwiftUI

enum Theme {
  static let s1: CGFloat = 4
  static let s2: CGFloat = 8
  static let s3: CGFloat = 12
  static let s4: CGFloat = 16
  static let s5: CGFloat = 20
  static let s6: CGFloat = 28

  static let cardRadius: CGFloat = 14
  static let rowRadius: CGFloat = 11

  static let cardFill = AnyShapeStyle(.background.opacity(0.45))
  static let cardStroke = AnyShapeStyle(.white.opacity(0.07))
  static let hoverFill = AnyShapeStyle(.primary.opacity(0.06))
  static let cardShadow = Color.black.opacity(0.14)

  static let hover = Animation.snappy(duration: 0.16)
  static let expand = Animation.snappy(duration: 0.22)
}

extension View {
  @ViewBuilder
  func glassCard(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
    if #available(macOS 26.0, *) {
      self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      self
        .background(Theme.cardFill, in: .rect(cornerRadius: cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Theme.cardStroke, lineWidth: 1)
        )
    }
  }

  @ViewBuilder
  func glassInteractive(cornerRadius: CGFloat = Theme.rowRadius) -> some View {
    if #available(macOS 26.0, *) {
      self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      self
        .background(Theme.cardFill, in: .rect(cornerRadius: cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Theme.cardStroke, lineWidth: 1)
        )
    }
  }
}

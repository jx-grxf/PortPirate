import SwiftUI

struct SettingsCard<Content: View>: View {
  var title: String?
  var subtitle: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.s2) {
      if let title {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.headline)
          if let subtitle {
            Text(subtitle)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, Theme.s2)
      }

      VStack(spacing: 0) { content }
        .glassCard()
        .shadow(color: Theme.cardShadow, radius: 9, y: 3)
    }
  }
}

struct SettingRow<Trailing: View>: View {
  let title: String
  var subtitle: String?
  var systemImage: String?
  var showsDivider: Bool = true
  @ViewBuilder var trailing: Trailing

  @State private var isHovering = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center, spacing: Theme.s3) {
        if let systemImage {
          Image(systemName: systemImage)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .font(.system(size: 15))
            .frame(width: 22)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
          if let subtitle {
            Text(subtitle)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer(minLength: Theme.s4)
        trailing
      }
      .padding(.horizontal, Theme.s3)
      .padding(.vertical, Theme.s3 - 1)
      .background(isHovering ? Theme.hoverFill : AnyShapeStyle(.clear))

      if showsDivider {
        Divider().padding(.leading, Theme.s3)
      }
    }
    .contentShape(.rect)
    .onHover { hovering in
      withAnimation(Theme.hover) { isHovering = hovering }
    }
  }
}

extension SettingRow where Trailing == EmptyView {
  init(title: String, subtitle: String? = nil, systemImage: String? = nil, showsDivider: Bool = true) {
    self.init(
      title: title,
      subtitle: subtitle,
      systemImage: systemImage,
      showsDivider: showsDivider
    ) { EmptyView() }
  }
}

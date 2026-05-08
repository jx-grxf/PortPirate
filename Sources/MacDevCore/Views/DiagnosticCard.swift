import SwiftUI

struct DiagnosticCard: View {
  let result: DiagnosticResult

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        StatusDot(result.severity)
        Text(result.title)
          .font(.callout)
          .bold()
      }

      Text(result.cause)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text(result.recommendedAction)
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)

      if let server = result.server {
        Text("PID \(server.processID) • \(server.commandLine)")
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .textSelection(.enabled)
      }
    }
    .padding(10)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

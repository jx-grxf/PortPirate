import AppKit
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .sidebar
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.material = material
    view.blendingMode = blendingMode
  }
}

private struct TransparentWindowConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      guard let window = view.window else { return }
      window.isOpaque = false
      window.backgroundColor = .clear
      window.titlebarAppearsTransparent = true
      window.styleMask.insert(.fullSizeContentView)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
  func translucentWindowBackground(
    material: NSVisualEffectView.Material = .sidebar
  ) -> some View {
    background(VisualEffectBackground(material: material).ignoresSafeArea())
      .background(TransparentWindowConfigurator())
  }
}

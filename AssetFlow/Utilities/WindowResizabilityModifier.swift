//
//  WindowResizabilityModifier.swift
//  AssetFlow
//
//  Created by Claude on 2026/03/15.
//

import AppKit
import SwiftUI

/// An `NSViewRepresentable` that finds its hosting `NSWindow` and adds the
/// `.resizable` style mask so the user can drag window edges to resize.
///
/// The `Settings` scene creates a non-resizable window and ignores
/// `.windowResizability(_:)`, so this workaround is required.
///
/// Usage: `.windowResizable()`
struct WindowResizabilityModifier: NSViewRepresentable {
  func makeNSView(context: Context) -> ResizabilityView {
    ResizabilityView()
  }

  func updateNSView(_ nsView: ResizabilityView, context: Context) {}

  final class ResizabilityView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.styleMask.insert(.resizable)
    }
  }
}

extension View {
  func windowResizable() -> some View {
    background(WindowResizabilityModifier())
  }
}

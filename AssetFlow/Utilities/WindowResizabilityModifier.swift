//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
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

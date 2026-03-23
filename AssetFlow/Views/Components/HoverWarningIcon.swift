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

import SwiftUI

/// A warning icon that shows a popover message on hover.
///
/// Uses `onHoverWhenUnlocked` to respect app lock state.
struct HoverWarningIcon: View {
  let message: String
  var systemName: String = "exclamationmark.triangle.fill"
  var color: Color = .yellow

  @State private var isHovering = false
  @Environment(\.isAppLocked) private var isLocked

  var body: some View {
    Image(systemName: systemName)
      .foregroundStyle(color)
      .onHoverWhenUnlocked { hovering in
        isHovering = hovering
      }
      .popover(
        isPresented: Binding(
          get: { !isLocked && isHovering },
          set: { if !$0 { isHovering = false } }
        ),
        arrowEdge: .bottom
      ) {
        Text(message)
          .font(.callout)
          .fixedSize(horizontal: false, vertical: true)
          .frame(idealWidth: 300, alignment: .leading)
          .padding()
      }
  }
}

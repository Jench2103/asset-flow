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

struct AppLockedKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var isAppLocked: Bool {
    get { self[AppLockedKey.self] }
    set { self[AppLockedKey.self] = newValue }
  }
}

// MARK: - Help

extension View {
  func helpWhenUnlocked(_ textKey: LocalizedStringKey?) -> some View {
    modifier(HelpWhenUnlockedModifier(textKey: textKey))
  }

  func helpWhenUnlocked(_ text: String) -> some View {
    modifier(HelpWhenUnlockedStringModifier(text: text))
  }
}

private struct HelpWhenUnlockedModifier: ViewModifier {
  let textKey: LocalizedStringKey?
  @Environment(\.isAppLocked) private var isLocked

  func body(content: Content) -> some View {
    // Always apply .help() to keep the view tree structure stable.
    // Switching between content.help() and bare content causes SwiftUI
    // to reset @FocusState on the modified view.
    content.help(isLocked || textKey == nil ? "" : textKey!)
  }
}

private struct HelpWhenUnlockedStringModifier: ViewModifier {
  let text: String
  @Environment(\.isAppLocked) private var isLocked

  @ViewBuilder
  func body(content: Content) -> some View {
    if !isLocked {
      content.help(text)
    } else {
      content
    }
  }
}

// MARK: - Hover

extension View {
  func onHoverWhenUnlocked(perform action: @escaping (Bool) -> Void) -> some View {
    modifier(OnHoverWhenUnlockedModifier(action: action))
  }

  func onContinuousHoverWhenUnlocked(
    coordinateSpace: some CoordinateSpaceProtocol = .local,
    perform action: @escaping (HoverPhase) -> Void
  ) -> some View {
    modifier(
      OnContinuousHoverWhenUnlockedModifier(coordinateSpace: coordinateSpace, action: action))
  }
}

private struct OnHoverWhenUnlockedModifier: ViewModifier {
  let action: (Bool) -> Void
  @Environment(\.isAppLocked) private var isLocked

  func body(content: Content) -> some View {
    content.onHover { isHovering in
      if isLocked {
        action(false)
      } else {
        action(isHovering)
      }
    }
  }
}

private struct OnContinuousHoverWhenUnlockedModifier<S: CoordinateSpaceProtocol>: ViewModifier {
  let coordinateSpace: S
  let action: (HoverPhase) -> Void
  @Environment(\.isAppLocked) private var isLocked

  func body(content: Content) -> some View {
    content.onContinuousHover(coordinateSpace: coordinateSpace) { phase in
      if isLocked {
        action(.ended)
      } else {
        action(phase)
      }
    }
  }
}

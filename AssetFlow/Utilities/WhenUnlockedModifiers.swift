//
//  WhenUnlockedModifiers.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/23.
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
}

private struct HelpWhenUnlockedModifier: ViewModifier {
  let textKey: LocalizedStringKey?
  @Environment(\.isAppLocked) private var isLocked

  @ViewBuilder
  func body(content: Content) -> some View {
    if let textKey, !isLocked {
      content.help(textKey)
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

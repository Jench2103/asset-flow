//
//  HelpWhenUnlockedModifier.swift
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

//
//  AnimationConstants.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/24.
//

import SwiftUI

enum AnimationConstants {
  /// Re-evaluated each access so runtime changes take effect immediately.
  private static var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  /// For content appearing/disappearing (empty states, conditional fields, banners).
  static var standard: Animation {
    reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.25)
  }

  /// For list item reordering.
  static var list: Animation {
    reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.2)
  }

  /// For chart data transitions when time range changes.
  static var chart: Animation {
    reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.25)
  }

  /// For numeric value changes (pairs with .contentTransition(.numericText())).
  static var numericText: Animation {
    reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.2)
  }
}

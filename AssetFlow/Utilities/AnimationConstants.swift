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

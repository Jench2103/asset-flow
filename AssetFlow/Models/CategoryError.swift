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

import Foundation

/// Error types for category operations.
enum CategoryError: LocalizedError, Equatable {
  case duplicateName(String)
  case cannotDelete(assetCount: Int)
  case emptyName
  case invalidTargetAllocation

  var errorDescription: String? {
    switch self {
    case .duplicateName(let name):
      return String(
        localized: "A category named '\(name)' already exists.",
        table: "Category")

    case .cannotDelete(let assetCount):
      return String(
        localized:
          "This category cannot be deleted because it has \(assetCount) asset(s) assigned. Reassign the assets first.",
        table: "Category")

    case .emptyName:
      return String(
        localized: "Category name cannot be empty.",
        table: "Category")

    case .invalidTargetAllocation:
      return String(
        localized: "Target allocation must be between 0% and 100%.",
        table: "Category")
    }
  }
}

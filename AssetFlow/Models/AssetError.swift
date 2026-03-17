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

/// Error types for asset operations.
enum AssetError: LocalizedError, Equatable {
  case cannotDelete(snapshotCount: Int)
  case duplicateIdentity(name: String, platform: String)

  var errorDescription: String? {
    switch self {
    case .cannotDelete(let snapshotCount):
      return String(
        localized:
          "This asset cannot be deleted because it has values in \(snapshotCount) snapshot(s). Remove the asset from all snapshots first.",
        table: "Asset")

    case .duplicateIdentity(let name, let platform):
      if platform.isEmpty {
        return String(
          localized:
            "An asset named '\(name)' already exists without a platform.",
          table: "Asset")
      }
      return String(
        localized:
          "An asset named '\(name)' on platform '\(platform)' already exists.",
        table: "Asset")
    }
  }
}

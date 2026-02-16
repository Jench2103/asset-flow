//
//  AssetError.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
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

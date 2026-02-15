//
//  Asset.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@Model
final class Asset {
  var id: UUID
  var name: String
  var platform: String

  @Relationship
  var category: Category?

  @Relationship(deleteRule: .deny, inverse: \SnapshotAssetValue.asset)
  var snapshotAssetValues: [SnapshotAssetValue]?

  init(
    name: String,
    platform: String = ""
  ) {
    self.id = UUID()
    self.name = name
    self.platform = platform
    self.category = nil
    self.snapshotAssetValues = []
  }

  /// Normalized identity for case-insensitive matching.
  ///
  /// Applies the SPEC Section 6.1 normalization:
  /// 1. Trim leading and trailing whitespace
  /// 2. Collapse multiple consecutive spaces to a single space
  /// 3. Lowercased for case-insensitive comparison
  var normalizedName: String {
    name
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression
      )
      .lowercased()
  }

  /// Normalized platform for case-insensitive matching.
  var normalizedPlatform: String {
    platform
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(
        of: "\\s+",
        with: " ",
        options: .regularExpression
      )
      .lowercased()
  }

  /// Combined normalized identity tuple for matching.
  var normalizedIdentity: String {
    "\(normalizedName)|\(normalizedPlatform)"
  }
}

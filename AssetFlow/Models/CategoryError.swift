//
//  CategoryError.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
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

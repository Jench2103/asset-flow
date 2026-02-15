//
//  PlatformError.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation

/// Error types for platform operations.
enum PlatformError: LocalizedError, Equatable {
  case emptyName
  case duplicateName(String)

  var errorDescription: String? {
    switch self {
    case .emptyName:
      return String(
        localized: "Platform name cannot be empty.",
        table: "Platform")

    case .duplicateName(let name):
      return String(
        localized: "A platform named '\(name)' already exists.",
        table: "Platform")
    }
  }
}

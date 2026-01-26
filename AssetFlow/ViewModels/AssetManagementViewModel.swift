//
//  AssetManagementViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation
import Observation
import SwiftData

/// ViewModel for managing asset operations (deletion, etc.)
///
/// Handles asset deletion with proper validation and error handling.
@Observable
@MainActor
class AssetManagementViewModel {
  var modelContext: ModelContext

  // MARK: - Deletion State

  /// The asset pending deletion (waiting for user confirmation)
  var assetToDelete: Asset?

  /// Whether to show the deletion confirmation dialog
  var showingDeleteConfirmation = false

  /// Error that occurred during deletion
  var deletionError: AssetDeletionError?

  /// Whether to show the deletion error alert
  var showingDeletionError = false

  // MARK: - Initializer

  /// Initializes the ViewModel with a model context.
  ///
  /// - Parameter modelContext: The `ModelContext` to use for data operations.
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Deletion Logic

  /// Initiates deletion of an asset by setting it for confirmation.
  ///
  /// - Parameter asset: The asset to delete.
  func initiateDelete(asset: Asset) {
    assetToDelete = asset
    showingDeleteConfirmation = true
    deletionError = nil
    showingDeletionError = false
  }

  /// Confirms and executes asset deletion.
  ///
  /// This method deletes the asset from the model context. SwiftData automatically
  /// cascades the deletion to associated Transactions and PriceHistory records.
  func confirmDelete() {
    guard let asset = assetToDelete else {
      return
    }

    // Delete the asset (cascade rules handle related data)
    modelContext.delete(asset)

    // Reset state
    assetToDelete = nil
    showingDeleteConfirmation = false
    deletionError = nil
    showingDeletionError = false
  }

  /// Cancels the deletion and resets the state.
  func cancelDelete() {
    assetToDelete = nil
    showingDeleteConfirmation = false
    deletionError = nil
    showingDeletionError = false
  }
}

// MARK: - Error Types

/// Errors that can occur during asset deletion
enum AssetDeletionError: LocalizedError {
  case deletionFailed(String)

  var errorDescription: String? {
    switch self {
    case .deletionFailed(let message):
      return "Failed to delete asset: \(message)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .deletionFailed:
      return "Please try again or restart the application."
    }
  }
}

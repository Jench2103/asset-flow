//
//  PriceHistoryManagementViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/20.
//

import Foundation
import Observation
import SwiftData

/// ViewModel for managing price history records (deletion flow, list state).
///
/// Handles deletion with proper validation, ensuring at least one price record
/// is always maintained for an asset.
@Observable
@MainActor
class PriceHistoryManagementViewModel {
  let asset: Asset
  var modelContext: ModelContext

  // MARK: - Deletion State

  /// The price record pending deletion (waiting for user confirmation)
  var recordToDelete: PriceHistory?

  /// Whether to show the deletion confirmation dialog
  var showingDeleteConfirmation = false

  /// Whether to show the last record alert
  var showingLastRecordAlert = false

  // MARK: - Computed Properties

  /// Price history sorted newest first
  var sortedPriceHistory: [PriceHistory] {
    (asset.priceHistory ?? []).sorted(by: { $0.date > $1.date })
  }

  /// Whether deletion is allowed (requires at least 2 records)
  var canDeleteRecords: Bool {
    recordCount >= 2
  }

  /// Number of price history records
  var recordCount: Int {
    asset.priceHistory?.count ?? 0
  }

  // MARK: - Initializer

  init(asset: Asset, modelContext: ModelContext) {
    self.asset = asset
    self.modelContext = modelContext
  }

  // MARK: - Deletion Logic

  /// Initiates deletion of a price record.
  ///
  /// If this is the last record, shows a "cannot delete" alert instead.
  func initiateDelete(record: PriceHistory) {
    if canDeleteRecords {
      recordToDelete = record
      showingDeleteConfirmation = true
      showingLastRecordAlert = false
    } else {
      recordToDelete = nil
      showingDeleteConfirmation = false
      showingLastRecordAlert = true
    }
  }

  /// Confirms and executes price record deletion.
  func confirmDelete() {
    guard let record = recordToDelete else { return }

    modelContext.delete(record)

    // Reset state
    recordToDelete = nil
    showingDeleteConfirmation = false
  }

  /// Cancels the deletion and resets state.
  func cancelDelete() {
    recordToDelete = nil
    showingDeleteConfirmation = false
    showingLastRecordAlert = false
  }
}

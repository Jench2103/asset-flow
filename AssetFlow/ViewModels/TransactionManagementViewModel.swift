//
//  TransactionManagementViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/1/27.
//

import Foundation
import Observation
import SwiftData

/// Error type for transaction deletion validation failures.
enum TransactionDeletionError: LocalizedError {
  case wouldCauseNegativeQuantity

  var errorDescription: String? {
    switch self {
    case .wouldCauseNegativeQuantity:
      return "Cannot Delete Transaction"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .wouldCauseNegativeQuantity:
      return
        "Deleting this transaction would cause the asset quantity to become negative."
        + "\n\nDelete or edit other transactions first to ensure the quantity remains valid."
    }
  }
}

/// ViewModel for managing transaction records (deletion flow, list state).
///
/// Handles deletion with validation ensuring the asset's quantity
/// does not become negative after removal.
@Observable
@MainActor
class TransactionManagementViewModel {
  let asset: Asset
  var modelContext: ModelContext

  // MARK: - Deletion State

  /// The transaction pending deletion (waiting for user confirmation)
  var transactionToDelete: Transaction?

  /// Whether to show the deletion confirmation dialog
  var showingDeleteConfirmation = false

  /// The deletion error if validation fails
  var deletionError: TransactionDeletionError?

  /// Whether to show the deletion error alert
  var showingDeletionError = false

  // MARK: - Computed Properties

  /// Transactions sorted by date, newest first
  var sortedTransactions: [Transaction] {
    (asset.transactions ?? []).sorted(by: { $0.transactionDate > $1.transactionDate })
  }

  /// Number of transactions for this asset
  var transactionCount: Int {
    asset.transactions?.count ?? 0
  }

  // MARK: - Initializer

  init(asset: Asset, modelContext: ModelContext) {
    self.asset = asset
    self.modelContext = modelContext
  }

  // MARK: - Deletion Validation

  /// Checks whether a transaction can be safely deleted without causing negative quantity.
  ///
  /// Removing a transaction reverses its quantity impact. For example, deleting a buy
  /// transaction reduces the asset's quantity. The resulting quantity must be >= 0.
  func canDelete(transaction: Transaction) -> Bool {
    let resultingQuantity = asset.quantity - transaction.quantityImpact
    return resultingQuantity >= 0
  }

  // MARK: - Deletion Logic

  /// Initiates deletion of a transaction.
  ///
  /// If deletion would cause negative quantity, shows an error alert instead.
  func initiateDelete(transaction: Transaction) {
    if canDelete(transaction: transaction) {
      transactionToDelete = transaction
      showingDeleteConfirmation = true
      deletionError = nil
      showingDeletionError = false
    } else {
      transactionToDelete = nil
      showingDeleteConfirmation = false
      deletionError = .wouldCauseNegativeQuantity
      showingDeletionError = true
    }
  }

  /// Confirms and executes transaction deletion.
  func confirmDelete() {
    guard let transaction = transactionToDelete else { return }

    modelContext.delete(transaction)

    // Reset state
    transactionToDelete = nil
    showingDeleteConfirmation = false
  }

  /// Cancels the deletion and resets state.
  func cancelDelete() {
    transactionToDelete = nil
    showingDeleteConfirmation = false
    deletionError = nil
    showingDeletionError = false
  }
}

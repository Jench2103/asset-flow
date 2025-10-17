//
//  PortfolioListViewModel.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import SwiftData
import os.log

/// ViewModel for managing portfolio list data
///
/// This ViewModel can be used to contain business logic for the portfolio list,
/// such as deletion or filtering logic.
@Observable
@MainActor
class PortfolioListViewModel {
  var modelContext: ModelContext
  private let logger = Logger(
    subsystem: "com.jench2103.AssetFlow",
    category: "PortfolioListViewModel")

  // MARK: - Deletion State

  /// The portfolio pending deletion (waiting for user confirmation)
  var portfolioToDelete: Portfolio?

  /// Whether to show the deletion confirmation dialog
  var showingDeleteConfirmation = false

  /// Error that occurred during deletion
  var deletionError: PortfolioDeletionError?

  /// Whether to show the deletion error alert
  var showingDeletionError = false

  /// Initializes the ViewModel with a model context.
  ///
  /// - Parameter modelContext: The `ModelContext` to use for data operations.
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // Note: The responsibility for fetching portfolios has been moved to the View
  // using the @Query property wrapper for automatic updates.

  // MARK: - Deletion Logic

  /// Validates if a portfolio can be deleted.
  ///
  /// Business rule: Only empty portfolios (no assets) can be deleted.
  ///
  /// - Parameter portfolio: The portfolio to validate for deletion
  /// - Returns: Success if portfolio is empty, failure with error if not
  func validateDeletion(of portfolio: Portfolio) -> Result<Void, PortfolioDeletionError> {
    logger.debug("Validating deletion for portfolio: \(portfolio.name)")

    guard portfolio.isEmpty else {
      logger.warning(
        "Cannot delete portfolio '\(portfolio.name)': contains \(portfolio.assetCount) assets")
      return .failure(.portfolioNotEmpty(assetCount: portfolio.assetCount))
    }

    logger.debug("Portfolio '\(portfolio.name)' is empty and can be deleted")
    return .success(())
  }

  /// Initiates the deletion process for a portfolio.
  ///
  /// This method validates the portfolio and either shows a confirmation dialog
  /// (if valid) or an error alert (if invalid).
  ///
  /// - Parameter portfolio: The portfolio to delete
  func initiateDelete(portfolio: Portfolio) {
    logger.debug("Initiating deletion for portfolio: \(portfolio.name)")

    // Validate before showing confirmation
    switch validateDeletion(of: portfolio) {
    case .success:
      portfolioToDelete = portfolio
      showingDeleteConfirmation = true

    case .failure(let error):
      deletionError = error
      showingDeletionError = true
    }
  }

  /// Confirms and executes the deletion of the portfolio.
  ///
  /// This method is called after the user confirms deletion in the alert dialog.
  /// It performs a final validation before deleting to handle edge cases where
  /// the portfolio state may have changed.
  func confirmDelete() {
    guard let portfolio = portfolioToDelete else {
      logger.error("confirmDelete called but portfolioToDelete is nil")
      return
    }

    logger.info("Deleting portfolio: \(portfolio.name)")

    // Final validation before deletion (edge case: state changed during confirmation)
    switch validateDeletion(of: portfolio) {
    case .success:
      modelContext.delete(portfolio)
      logger.info("Successfully deleted portfolio: \(portfolio.name)")

    case .failure(let error):
      // Edge case: portfolio state changed between confirmation and execution
      logger.error("Validation failed during deletion: \(error.localizedDescription)")
      deletionError = error
      showingDeletionError = true
    }

    // Reset state
    portfolioToDelete = nil
    showingDeleteConfirmation = false
  }

  /// Cancels the deletion process.
  ///
  /// This method is called when the user cancels the confirmation dialog.
  func cancelDelete() {
    logger.debug("Deletion cancelled for portfolio: \(self.portfolioToDelete?.name ?? "unknown")")
    portfolioToDelete = nil
    showingDeleteConfirmation = false
  }
}

// MARK: - Portfolio Deletion Error

/// Errors that can occur during portfolio deletion
enum PortfolioDeletionError: LocalizedError {
  case portfolioNotEmpty(assetCount: Int)
  case deletionFailed(underlyingError: Error)

  var errorDescription: String? {
    switch self {
    case .portfolioNotEmpty:
      return "Cannot delete portfolio"

    case .deletionFailed(let error):
      return "Failed to delete portfolio: \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .portfolioNotEmpty(let count):
      let assetWord = count == 1 ? "asset" : "assets"
      return
        "This portfolio contains \(count) \(assetWord). Remove all assets before deleting the portfolio."

    case .deletionFailed:
      return "Please try again. If the problem persists, restart the application."
    }
  }
}

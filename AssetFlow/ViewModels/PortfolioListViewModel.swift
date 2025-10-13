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

  /// Initializes the ViewModel with a model context.
  ///
  /// - Parameter modelContext: The `ModelContext` to use for data operations.
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // Note: The responsibility for fetching portfolios has been moved to the View
  // using the @Query property wrapper for automatic updates.
}

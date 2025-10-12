//
//  PortfolioListViewModel.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import SwiftData

/// ViewModel for managing portfolio list data
///
/// This ViewModel fetches and manages portfolio data from SwiftData.
@Observable
class PortfolioListViewModel {
  var portfolios: [Portfolio] = []
  private var modelContext: ModelContext

  /// Initializes the ViewModel with a model context.
  ///
  /// - Parameter modelContext: The `ModelContext` to use for data operations.
  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  /// Fetches all portfolios from the SwiftData store.
  func fetchPortfolios() {
    do {
      let descriptor = FetchDescriptor<Portfolio>(sortBy: [SortDescriptor(\Portfolio.name)])
      self.portfolios = try modelContext.fetch(descriptor)
    } catch {
      // For now, just print the error. In a real app, handle this more gracefully.
      print("Fetch failed: \(error)")
    }
  }
}

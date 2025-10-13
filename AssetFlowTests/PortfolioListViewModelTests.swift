//
//  PortfolioListViewModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

/// Tests for PortfolioListViewModel
@Suite("PortfolioListViewModel Tests")
@MainActor
struct PortfolioListViewModelTests {

  @Test("ViewModel initializes and holds the correct model context")
  func viewModelInitializesAndHoldsContext() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Act
    let viewModel = PortfolioListViewModel(modelContext: context)

    // Assert
    // Verify that the ViewModel correctly stores the context it was given.
    #expect(viewModel.modelContext === context)
  }
}

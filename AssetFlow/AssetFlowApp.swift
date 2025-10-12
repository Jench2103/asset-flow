//
//  AssetFlowApp.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import SwiftData
import SwiftUI

@main
struct AssetFlowApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Asset.self,
      Portfolio.self,
      Transaction.self,
      InvestmentPlan.self,
    ])

    var modelConfiguration: ModelConfiguration
    // Check for UI testing launch argument
    if CommandLine.arguments.contains("UI-Testing") {
      // Use in-memory store for UI tests
      modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    } else {
      // Default configuration for production
      modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

      // If testing, pre-populate data
      if CommandLine.arguments.contains("UI-Testing") {
        // Avoid populating if testing the empty state
        if !CommandLine.arguments.contains("EmptyPortfolios") {
          let context = container.mainContext
          // Add mock data for UI tests
          context.insert(
            Portfolio(name: "Tech Stocks", portfolioDescription: "High-growth tech portfolio"))
          context.insert(
            Portfolio(name: "Real Estate", portfolioDescription: "Residential properties"))
          context.insert(
            Portfolio(name: "Retirement Fund", portfolioDescription: "Long-term investments"))
        }
      }

      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      let viewModel = PortfolioListViewModel(modelContext: sharedModelContainer.mainContext)
      PortfolioListView(viewModel: viewModel)
    }
    .modelContainer(sharedModelContainer)
  }
}

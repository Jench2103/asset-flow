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
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      // Check if running in UI test mode
      if CommandLine.arguments.contains("UI-Testing") {
        // Show PortfolioListView for testing
        PortfolioListView()
      } else {
        // Normal app flow - for now, show PortfolioListView as main screen
        // TODO: Replace with proper navigation structure when implementing full app
        PortfolioListView()
      }
    }
    .modelContainer(sharedModelContainer)
  }
}

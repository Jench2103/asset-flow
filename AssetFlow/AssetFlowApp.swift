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
  let sharedModelContainer: ModelContainer

  init() {
    let schema = Schema([
      Asset.self,
      Portfolio.self,
      Transaction.self,
      InvestmentPlan.self,
      PriceHistory.self,
      RegularSavingPlan.self,
    ])

    // Always use the default, persistent database configuration.
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      // Initialize the container for the application.
      sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      // If the container fails to load, something is seriously wrong.
      fatalError("Could not create ModelContainer: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}

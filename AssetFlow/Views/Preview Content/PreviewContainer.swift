//
//  PreviewContainer.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/12.
//

import Foundation
import SwiftData

/// A container for providing a `ModelContainer` for SwiftUI previews.
class PreviewContainer {
  /// A shared, in-memory `ModelContainer` for SwiftUI previews.
  static let container: ModelContainer = {
    do {
      let schema = Schema([
        Portfolio.self,
        Asset.self,
        Transaction.self,
        InvestmentPlan.self,
      ])
      let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
      let container = try ModelContainer(for: schema, configurations: [configuration])
      return container
    } catch {
      fatalError("Failed to create in-memory model container for previews: \(error)")
    }
  }()
}

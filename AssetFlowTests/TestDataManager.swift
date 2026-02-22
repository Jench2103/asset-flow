//
//  TestDataManager.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@testable import AssetFlow

@MainActor
class TestDataManager {
  /// Creates a new, empty, in-memory `ModelContainer` for testing.
  ///
  /// Each call to this function returns a brand new container, ensuring that
  /// tests do not interfere with each other.
  ///
  /// - Returns: A new `ModelContainer` configured for in-memory storage.
  static func createInMemoryContainer() -> ModelContainer {
    let schema = Schema([
      Category.self,
      Asset.self,
      Snapshot.self,
      SnapshotAssetValue.self,
      CashFlowOperation.self,
      ExchangeRate.self,
    ])
    // Use a unique name per container to ensure true isolation.
    // Without a unique name, ModelConfiguration(isStoredInMemoryOnly: true) may
    // share the same backing store across calls, causing test interference.
    let configuration = ModelConfiguration(
      UUID().uuidString,
      schema: schema,
      isStoredInMemoryOnly: true
    )

    do {
      let container = try ModelContainer(for: schema, configurations: [configuration])
      return container
    } catch {
      fatalError("Failed to create in-memory model container: \(error)")
    }
  }
}

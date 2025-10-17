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
      Portfolio.self,
      Asset.self,
      Transaction.self,
      InvestmentPlan.self,
      PriceHistory.self,
    ])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)

    do {
      let container = try ModelContainer(for: schema, configurations: [configuration])
      return container
    } catch {
      fatalError("Failed to create in-memory model container: \(error)")
    }
  }
}

//
//  SnapshotDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Data for category allocation display.
struct CategoryAllocationData: Sendable {
  let categoryName: String
  let value: Decimal
  let percentage: Decimal
}

/// ViewModel for the Snapshot detail screen.
///
/// Manages asset add/edit/remove, cash flow add/edit/remove,
/// and category allocation summary.
@Observable
@MainActor
class SnapshotDetailViewModel {
  let snapshot: Snapshot
  private let modelContext: ModelContext

  /// Direct asset values in this snapshot.
  var assetValues: [SnapshotAssetValue] = []

  /// Cash flow operations in this snapshot.
  var cashFlowOperations: [CashFlowOperation] = []

  /// Exchange rate data for currency conversion.
  var exchangeRate: ExchangeRate?

  /// Whether exchange rates are currently being fetched.
  var isFetchingRates = false

  /// Error message from exchange rate fetch.
  var ratesFetchError: String?

  init(snapshot: Snapshot, modelContext: ModelContext) {
    self.snapshot = snapshot
    self.modelContext = modelContext
  }

  // MARK: - Computed Properties

  /// Display currency for this snapshot.
  private var displayCurrency: String {
    SettingsService.shared.mainCurrency
  }

  /// Total portfolio value for this snapshot, converted to display currency.
  var totalValue: Decimal {
    CurrencyConversionService.totalValue(
      for: snapshot, displayCurrency: displayCurrency, exchangeRate: exchangeRate)
  }

  /// Net cash flow for this snapshot, converted to display currency.
  var netCashFlow: Decimal {
    CurrencyConversionService.netCashFlow(
      for: snapshot, displayCurrency: displayCurrency, exchangeRate: exchangeRate)
  }

  /// Asset values sorted by platform (alphabetical), then asset name (alphabetical).
  var sortedAssetValues: [SnapshotAssetValue] {
    assetValues
      .filter { $0.asset != nil }
      .sorted { lhs, rhs in
        let lhsAsset = lhs.asset!
        let rhsAsset = rhs.asset!
        if lhsAsset.platform != rhsAsset.platform {
          return lhsAsset.platform.localizedCaseInsensitiveCompare(rhsAsset.platform)
            == .orderedAscending
        }
        return lhsAsset.name.localizedCaseInsensitiveCompare(rhsAsset.name) == .orderedAscending
      }
  }

  /// Cash flow operations sorted by description for stable display order.
  var sortedCashFlowOperations: [CashFlowOperation] {
    cashFlowOperations.sorted { $0.cashFlowDescription < $1.cashFlowDescription }
  }

  /// Category allocation summary for this snapshot, with currency conversion.
  var categoryAllocations: [CategoryAllocationData] {
    let total = totalValue
    guard total > 0 else { return [] }

    let catValues = CurrencyConversionService.categoryValues(
      for: snapshot, displayCurrency: displayCurrency, exchangeRate: exchangeRate)

    return catValues.compactMap { name, value in
      let displayName = name.isEmpty ? "Uncategorized" : name
      return CategoryAllocationData(
        categoryName: displayName,
        value: value,
        percentage: CalculationService.categoryAllocation(
          categoryValue: value, totalValue: total)
      )
    }.sorted { $0.value > $1.value }
  }

  // MARK: - Load Data

  /// Loads (or reloads) asset values and cash flow operations for the snapshot.
  func loadData() {
    assetValues = snapshot.assetValues ?? []
    cashFlowOperations = snapshot.cashFlowOperations ?? []
    exchangeRate = snapshot.exchangeRate
  }

  /// Fetches exchange rates if not already attached to this snapshot.
  func fetchExchangeRatesIfNeeded() async {
    guard !isFetchingRates else { return }

    guard snapshot.exchangeRate == nil else {
      exchangeRate = snapshot.exchangeRate
      return
    }

    // Check if any assets use a different currency from the display currency
    let assetValues = snapshot.assetValues ?? []
    let cashFlows = snapshot.cashFlowOperations ?? []
    let display = displayCurrency.lowercased()

    let needsConversion =
      assetValues.contains {
        let c = $0.asset?.currency ?? ""
        return !c.isEmpty && c.lowercased() != display
      }
      || cashFlows.contains {
        !$0.currency.isEmpty && $0.currency.lowercased() != display
      }

    guard needsConversion else { return }

    isFetchingRates = true
    ratesFetchError = nil

    do {
      let service = ExchangeRateService()
      let rates = try await service.fetchRates(
        for: snapshot.date, baseCurrency: display)
      let ratesJSON = try JSONEncoder().encode(rates)

      let er = ExchangeRate(
        baseCurrency: display,
        ratesJSON: ratesJSON,
        fetchDate: snapshot.date
      )
      er.snapshot = snapshot
      modelContext.insert(er)

      exchangeRate = er
      isFetchingRates = false
    } catch {
      ratesFetchError = error.localizedDescription
      isFetchingRates = false
    }
  }

  // MARK: - Add Asset: Existing

  /// Adds an existing asset to this snapshot with the given market value.
  ///
  /// - Throws: `SnapshotError.assetAlreadyInSnapshot` if the asset is already in this snapshot.
  func addExistingAsset(_ asset: Asset, marketValue: Decimal) throws {
    // Check if asset already exists in this snapshot
    let existingValues = snapshot.assetValues ?? []
    if existingValues.contains(where: { $0.asset?.id == asset.id }) {
      throw SnapshotError.assetAlreadyInSnapshot(asset.name)
    }

    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    modelContext.insert(sav)
  }

  // MARK: - Add Asset: New

  /// Creates a new asset (or reuses an existing one) and adds it to this snapshot.
  ///
  /// - Throws: `SnapshotError.assetAlreadyInSnapshot` if the (name, platform) already exists
  ///   in this snapshot.
  func addNewAsset(
    name: String,
    platform: String,
    category: Category?,
    marketValue: Decimal,
    currency: String = ""
  ) throws {
    // Normalize for matching
    let normalizedName = name.normalizedForIdentity
    let normalizedPlatform = platform.normalizedForIdentity

    // Check if this asset identity already exists in the snapshot
    let existingValues = snapshot.assetValues ?? []
    if existingValues.contains(where: { sav in
      guard let asset = sav.asset else { return false }
      return asset.normalizedName == normalizedName
        && asset.normalizedPlatform == normalizedPlatform
    }) {
      throw SnapshotError.assetAlreadyInSnapshot(name)
    }

    // Find or create the asset record
    let asset = modelContext.findOrCreateAsset(name: name, platform: platform)

    // Assign currency if provided
    if !currency.isEmpty {
      asset.currency = currency
    }

    // Assign category if provided
    if let category = category {
      asset.category = category
    }

    // Create the SnapshotAssetValue
    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    modelContext.insert(sav)
  }

  // MARK: - Edit Asset Value

  /// Updates the market value of a direct SnapshotAssetValue.
  func editAssetValue(_ sav: SnapshotAssetValue, newValue: Decimal) throws {
    sav.marketValue = newValue
  }

  // MARK: - Remove Asset

  /// Removes a SnapshotAssetValue from the snapshot. The Asset record is preserved.
  func removeAsset(_ sav: SnapshotAssetValue) {
    modelContext.delete(sav)
  }

  // MARK: - Cash Flow Operations

  /// Adds a new cash flow operation to this snapshot.
  ///
  /// - Throws: `SnapshotError.duplicateCashFlowDescription` if the description already exists.
  func addCashFlow(description: String, amount: Decimal, currency: String = "") throws {
    let operations = snapshot.cashFlowOperations ?? []
    let normalizedDesc = description.trimmingCharacters(in: .whitespaces).lowercased()

    if operations.contains(where: {
      $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()
        == normalizedDesc
    }) {
      throw SnapshotError.duplicateCashFlowDescription(description)
    }

    let operation = CashFlowOperation(cashFlowDescription: description, amount: amount)
    operation.currency = currency
    operation.snapshot = snapshot
    modelContext.insert(operation)
  }

  /// Edits an existing cash flow operation.
  ///
  /// - Throws: `SnapshotError.duplicateCashFlowDescription` if the new description conflicts
  ///   with another operation in this snapshot.
  func editCashFlow(
    _ operation: CashFlowOperation,
    newDescription: String,
    newAmount: Decimal
  ) throws {
    let operations = snapshot.cashFlowOperations ?? []
    let normalizedNew = newDescription.trimmingCharacters(in: .whitespaces).lowercased()
    let normalizedOld =
      operation.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()

    // Only check for duplicates if the description actually changed
    if normalizedNew != normalizedOld {
      if operations.contains(where: {
        $0.id != operation.id
          && $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()
            == normalizedNew
      }) {
        throw SnapshotError.duplicateCashFlowDescription(newDescription)
      }
    }

    operation.cashFlowDescription = newDescription
    operation.amount = newAmount
  }

  /// Removes a cash flow operation from the snapshot.
  func removeCashFlow(_ operation: CashFlowOperation) {
    modelContext.delete(operation)
  }

  // MARK: - Delete Snapshot

  /// Deletes this snapshot from the model context.
  func deleteSnapshot() {
    modelContext.delete(snapshot)
  }

  /// Returns data for the delete confirmation dialog.
  func deleteConfirmationData() -> SnapshotConfirmationData {
    SnapshotConfirmationData(
      date: snapshot.date,
      assetCount: snapshot.assetValues?.count ?? 0,
      cashFlowCount: snapshot.cashFlowOperations?.count ?? 0
    )
  }

  // MARK: - Category Resolution

  /// Resolves a category by name, reusing an existing one (case-insensitive) or creating a new one.
  func resolveCategory(name: String) -> Category? {
    modelContext.resolveCategory(name: name)
  }

}

//
//  ImportViewModel+Helpers.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

// MARK: - Duplicate Detection, Revalidation, Import Execution, and Helpers

extension ImportViewModel {

  // MARK: - Duplicate Detection (CSV vs Snapshot)

  func detectAssetSnapshotDuplicates(rows: [AssetCSVRow]) -> [CSVError] {
    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)

    // Find existing snapshot for this date
    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []
    guard let existingSnapshot = allSnapshots.first(where: { $0.date == normalizedDate }) else {
      return []
    }

    let existingValues = existingSnapshot.assetValues ?? []
    var errors: [CSVError] = []

    for (index, row) in rows.enumerated() {
      let normalizedName = normalizeString(row.assetName)
      let normalizedPlatform = normalizeString(row.platform)

      let isDuplicate = existingValues.contains { sav in
        guard let asset = sav.asset else { return false }
        return asset.normalizedName == normalizedName
          && asset.normalizedPlatform == normalizedPlatform
      }

      if isDuplicate {
        errors.append(
          CSVError(
            row: index + 2, column: nil,
            message: String(
              localized:
                "Asset '\(row.assetName)' (platform: '\(row.platform)') already exists in the snapshot for this date.",
              table: "Import"
            )))
      }
    }

    return errors
  }

  func detectCashFlowSnapshotDuplicates(rows: [CashFlowCSVRow]) -> [CSVError] {
    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)

    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []
    guard let existingSnapshot = allSnapshots.first(where: { $0.date == normalizedDate }) else {
      return []
    }

    let existingOps = existingSnapshot.cashFlowOperations ?? []
    var errors: [CSVError] = []

    for (index, row) in rows.enumerated() {
      let normalizedDesc = row.description.trimmingCharacters(in: .whitespaces).lowercased()

      let isDuplicate = existingOps.contains {
        $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased() == normalizedDesc
      }

      if isDuplicate {
        errors.append(
          CSVError(
            row: index + 2, column: nil,
            message: String(
              localized:
                "Cash flow '\(row.description)' already exists in the snapshot for this date.",
              table: "Import"
            )))
      }
    }

    return errors
  }

  // MARK: - Revalidation

  /// Re-runs duplicate detection considering only included rows.
  func revalidate() {
    switch importType {
    case .assets:
      revalidateAssets()

    case .cashFlows:
      revalidateCashFlows()
    }
  }

  private func revalidateAssets() {
    let includedRows = assetPreviewRows.filter { $0.isIncluded }.map { $0.csvRow }

    // Re-detect within-CSV duplicates on included rows only
    let withinCSVErrors = CSVParsingService.detectAssetDuplicates(rows: includedRows)

    // Re-detect CSV-vs-snapshot duplicates on included rows only
    let snapshotErrors = detectAssetSnapshotDuplicates(rows: includedRows)

    validationErrors = parsingErrors + withinCSVErrors + snapshotErrors
  }

  private func revalidateCashFlows() {
    let includedRows = cashFlowPreviewRows.filter { $0.isIncluded }.map { $0.csvRow }

    let withinCSVErrors = CSVParsingService.detectCashFlowDuplicates(rows: includedRows)
    let snapshotErrors = detectCashFlowSnapshotDuplicates(rows: includedRows)

    validationErrors = parsingErrors + withinCSVErrors + snapshotErrors
  }

  // MARK: - Import Execution

  func findOrCreateSnapshot(date: Date) -> Snapshot {
    let descriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(descriptor)) ?? []

    if let existing = allSnapshots.first(where: { $0.date == date }) {
      return existing
    }

    let snapshot = Snapshot(date: date)
    modelContext.insert(snapshot)
    return snapshot
  }

  func executeAssetImport(snapshot: Snapshot) {
    let includedRows = assetPreviewRows.filter { $0.isIncluded }

    for previewRow in includedRows {
      let row = previewRow.csvRow
      let asset = findOrCreateAsset(name: row.assetName, platform: row.platform)

      // Assign category if selected
      if let category = selectedCategory {
        asset.category = category
      }

      // Create SnapshotAssetValue
      let sav = SnapshotAssetValue(marketValue: row.marketValue)
      sav.snapshot = snapshot
      sav.asset = asset
      modelContext.insert(sav)
    }
  }

  func executeCashFlowImport(snapshot: Snapshot) {
    let includedRows = cashFlowPreviewRows.filter { $0.isIncluded }

    for previewRow in includedRows {
      let row = previewRow.csvRow
      let operation = CashFlowOperation(
        cashFlowDescription: row.description, amount: row.amount)
      operation.snapshot = snapshot
      modelContext.insert(operation)
    }
  }

  func findOrCreateAsset(name: String, platform: String) -> Asset {
    let normalizedName = normalizeString(name)
    let normalizedPlatform = normalizeString(platform)

    let descriptor = FetchDescriptor<Asset>()
    let allAssets = (try? modelContext.fetch(descriptor)) ?? []

    if let existing = allAssets.first(where: {
      $0.normalizedName == normalizedName && $0.normalizedPlatform == normalizedPlatform
    }) {
      return existing
    }

    let newAsset = Asset(name: name, platform: platform)
    modelContext.insert(newAsset)
    return newAsset
  }

  // MARK: - Helpers

  func clearLoadedData() {
    assetPreviewRows = []
    cashFlowPreviewRows = []
    validationErrors = []
    validationWarnings = []
    parsingErrors = []
    selectedFileURL = nil
    importError = nil
  }

  func fetchAllAssets() -> [Asset] {
    let descriptor = FetchDescriptor<Asset>()
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  func normalizeString(_ string: String) -> String {
    string
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .lowercased()
  }
}

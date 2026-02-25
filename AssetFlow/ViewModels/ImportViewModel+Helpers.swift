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
    // Clear per-row duplicate errors first (marketValueWarning is set during rebuild)
    for idx in assetPreviewRows.indices {
      assetPreviewRows[idx].duplicateError = nil
      assetPreviewRows[idx].snapshotDuplicateError = nil
    }

    // Detect within-CSV duplicates on included rows, assign per-row
    var seenIdentities: [String: Int] = [:]
    for (index, row) in assetPreviewRows.enumerated() where row.isIncluded {
      let identity = CSVParsingService.normalizedAssetIdentity(row: row.csvRow)
      if let firstIndex = seenIdentities[identity] {
        let firstRow = assetPreviewRows[firstIndex]
        let platformLabel =
          row.csvRow.platform.isEmpty
          ? String(localized: "None", table: "Import")
          : row.csvRow.platform
        assetPreviewRows[index].duplicateError = String(
          localized:
            "Duplicate asset '\(row.csvRow.assetName)' (platform: '\(platformLabel)') — first appeared as '\(firstRow.csvRow.assetName)'.",
          table: "Import")
      } else {
        seenIdentities[identity] = index
      }
    }

    // Detect CSV-vs-snapshot duplicates on included rows, assign per-row.
    // Note: uses String.normalizedForIdentity (equivalent to CSVParsingService.normalizedAssetIdentity)
    // because we compare against stored Asset.normalizedName/normalizedPlatform model properties.
    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)
    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []
    if let existingSnapshot = allSnapshots.first(where: { $0.date == normalizedDate }) {
      let existingValues = existingSnapshot.assetValues ?? []
      for (index, row) in assetPreviewRows.enumerated() where row.isIncluded {
        let normalizedName = row.csvRow.assetName.normalizedForIdentity
        let normalizedPlatform = row.csvRow.platform.normalizedForIdentity
        let isDuplicate = existingValues.contains { sav in
          guard let asset = sav.asset else { return false }
          return asset.normalizedName == normalizedName
            && asset.normalizedPlatform == normalizedPlatform
        }
        if isDuplicate {
          let platformLabel =
            row.csvRow.platform.isEmpty
            ? String(localized: "None", table: "Import")
            : row.csvRow.platform
          assetPreviewRows[index].snapshotDuplicateError = String(
            localized:
              "Asset '\(row.csvRow.assetName)' (platform: '\(platformLabel)') already exists in the snapshot for this date.",
            table: "Import")
        }
      }
    }

    // Parsing errors stay in validationErrors — these represent rows that failed to parse
    // and don't appear in the preview (e.g., empty name, unparseable value, missing columns)
    validationErrors = parsingErrors

    // File-level warnings only (row <= 1) go into validationWarnings;
    // row-level warnings are shown as per-row popovers via marketValueWarning
    validationWarnings = baseAssetWarnings.filter { $0.row <= 1 }
  }

  private func revalidateCashFlows() {
    // Clear all per-row errors first
    for idx in cashFlowPreviewRows.indices {
      cashFlowPreviewRows[idx].duplicateError = nil
      cashFlowPreviewRows[idx].snapshotDuplicateError = nil
    }

    // Detect within-CSV duplicates on included rows, assign per-row
    var seenDescriptions: [String: Int] = [:]
    for (index, row) in cashFlowPreviewRows.enumerated() where row.isIncluded {
      let normalized = row.csvRow.description.lowercased()
        .trimmingCharacters(in: .whitespaces)
      if let firstIndex = seenDescriptions[normalized] {
        let firstRow = cashFlowPreviewRows[firstIndex]
        cashFlowPreviewRows[index].duplicateError = String(
          localized:
            "Duplicate description '\(row.csvRow.description)' — first appeared as '\(firstRow.csvRow.description)'.",
          table: "Import")
      } else {
        seenDescriptions[normalized] = index
      }
    }

    // Detect CSV-vs-snapshot duplicates on included rows, assign per-row
    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)
    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []
    if let existingSnapshot = allSnapshots.first(where: { $0.date == normalizedDate }) {
      let existingOps = existingSnapshot.cashFlowOperations ?? []
      for (index, row) in cashFlowPreviewRows.enumerated() where row.isIncluded {
        let normalizedDesc = row.csvRow.description.trimmingCharacters(in: .whitespaces)
          .lowercased()
        let isDuplicate = existingOps.contains {
          $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()
            == normalizedDesc
        }
        if isDuplicate {
          cashFlowPreviewRows[index].snapshotDuplicateError = String(
            localized:
              "Cash flow '\(row.csvRow.description)' already exists in the snapshot for this date.",
            table: "Import")
        }
      }
    }

    // Parsing errors stay in validationErrors — rows that failed to parse
    validationErrors = parsingErrors

    // File-level warnings only (row <= 1) go into validationWarnings;
    // row-level warnings are shown as per-row popovers via amountWarning
    validationWarnings = baseCashFlowWarnings.filter { $0.row <= 1 }
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
      let asset = modelContext.findOrCreateAsset(name: row.assetName, platform: row.platform)

      // Assign currency only when the CSV explicitly provides one
      let rowCurrency = row.currency
      if !rowCurrency.isEmpty {
        asset.currency = rowCurrency
      }

      // Assign category based on apply mode
      if let category = selectedCategory {
        switch categoryApplyMode {
        case .overrideAll:
          asset.category = category

        case .fillEmptyOnly:
          if asset.category == nil {
            asset.category = category
          }
        }
      }

      // Create SnapshotAssetValue
      let sav = SnapshotAssetValue(marketValue: row.marketValue)
      sav.snapshot = snapshot
      sav.asset = asset
      modelContext.insert(sav)
    }

    // Copy-forward: copy assets from selected platforms in prior snapshot
    if copyForwardEnabled {
      executeCopyForward(snapshot: snapshot)
    }
  }

  /// Copies asset values from selected platforms in the most recent prior snapshot.
  private func executeCopyForward(snapshot: Snapshot) {
    let selectedPlatforms = copyForwardPlatforms.filter { $0.isSelected }
    guard !selectedPlatforms.isEmpty else { return }

    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)

    // Find the most recent prior snapshot
    let snapshotDescriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []

    let priorSnapshots =
      allSnapshots
      .filter { $0.date < normalizedDate }
      .sorted { $0.date > $1.date }

    guard let latestPrior = priorSnapshots.first else { return }

    let selectedPlatformNames = Set(selectedPlatforms.map { $0.platformName.lowercased() })
    let priorValues = latestPrior.assetValues ?? []

    // Track assets already in the snapshot to avoid duplicates
    let existingAssetIDs = Set((snapshot.assetValues ?? []).compactMap { $0.asset?.id })

    for priorSAV in priorValues {
      guard let asset = priorSAV.asset else { continue }
      guard selectedPlatformNames.contains(asset.platform.lowercased()) else { continue }
      guard !existingAssetIDs.contains(asset.id) else { continue }

      let sav = SnapshotAssetValue(marketValue: priorSAV.marketValue)
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
      let rowCurrency = row.currency
      if !rowCurrency.isEmpty {
        operation.currency = rowCurrency
      }
      operation.snapshot = snapshot
      modelContext.insert(operation)
    }
  }

  // MARK: - Helpers

  func clearLoadedData() {
    assetPreviewRows = []
    cashFlowPreviewRows = []
    validationErrors = []
    validationWarnings = []
    parsingErrors = []
    selectedFileURL = nil
    selectedFileData = nil
    importError = nil
    platformApplyMode = .overrideAll
    categoryApplyMode = .overrideAll
    copyForwardPlatforms = []
    baseAssetRows = []
    baseAssetParsingErrors = []
    baseAssetWarnings = []
    baseCashFlowWarnings = []
    excludedAssetIndices = []
  }

  func fetchAllAssets() -> [Asset] {
    let descriptor = FetchDescriptor<Asset>()
    return (try? modelContext.fetch(descriptor)) ?? []
  }

}

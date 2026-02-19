//
//  ImportViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Information about a platform available for copy-forward during import.
struct CopyForwardPlatformInfo: Identifiable {
  let platformName: String
  let assetCount: Int
  let sourceSnapshotDate: Date
  var isSelected: Bool

  var id: String { platformName }
}

/// ViewModel for the CSV Import screen.
///
/// Manages import type selection, file loading, CSV parsing (via CSVParsingService),
/// validation, duplicate detection against existing snapshot data, preview row management,
/// and import execution per SPEC Section 4.
@Observable
@MainActor
class ImportViewModel {
  let modelContext: ModelContext
  private let settingsService: SettingsService

  // MARK: - State

  /// Selected import type (Assets or Cash Flows).
  var importType: ImportType = .assets {
    didSet {
      guard importType != oldValue else { return }
      clearLoadedData()
    }
  }

  /// Selected file URL (for display purposes).
  var selectedFileURL: URL?

  /// Snapshot date for the import (defaults to today).
  var snapshotDate: Date = Date() {
    didSet {
      guard snapshotDate != oldValue else { return }
      revalidate()
      computeCopyForwardPlatforms()
    }
  }

  /// Whether to copy assets from other platforms during import.
  var copyForwardEnabled: Bool = true

  /// Platforms available for copy-forward, computed from prior snapshots.
  var copyForwardPlatforms: [CopyForwardPlatformInfo] = []

  /// Import-level platform override (nil = use CSV per-row values).
  var selectedPlatform: String?

  /// Import-level category assignment (nil = uncategorized).
  var selectedCategory: Category?

  /// Preview rows for asset CSV import.
  var assetPreviewRows: [AssetPreviewRow] = []

  /// Preview rows for cash flow CSV import.
  var cashFlowPreviewRows: [CashFlowPreviewRow] = []

  /// Validation errors (block import).
  var validationErrors: [CSVError] = []

  /// Validation warnings (allow import with acknowledgment).
  var validationWarnings: [CSVWarning] = []

  /// Error from import execution (e.g., future date).
  var importError: String?

  /// Whether a file has been loaded but not yet imported.
  var hasUnsavedChanges: Bool = false

  /// Snapshot created or updated by the last successful import, for navigation.
  var importedSnapshot: Snapshot?

  /// Parsing errors from the initial CSV load (empty names, unparseable values).
  /// Stored separately so revalidation can preserve them alongside re-computed duplicate errors.
  var parsingErrors: [CSVError] = []

  // MARK: - Computed Properties

  /// Whether the Import button should be disabled.
  var isImportDisabled: Bool {
    let hasIncludedRows: Bool
    switch importType {
    case .assets:
      hasIncludedRows = assetPreviewRows.contains { $0.isIncluded }

    case .cashFlows:
      hasIncludedRows = cashFlowPreviewRows.contains { $0.isIncluded }
    }
    return !hasIncludedRows || !validationErrors.isEmpty
  }

  // MARK: - Init

  init(modelContext: ModelContext, settingsService: SettingsService? = nil) {
    self.modelContext = modelContext
    let resolvedService = settingsService ?? SettingsService.shared
    self.settingsService = resolvedService

    let defaultPlatform = resolvedService.defaultPlatform
    if !defaultPlatform.isEmpty {
      self.selectedPlatform = defaultPlatform
    }
  }

  // MARK: - File Loading

  /// Loads and parses CSV data based on the current import type.
  ///
  /// - Parameter data: Raw CSV file data (UTF-8).
  func loadCSVData(_ data: Data) {
    importError = nil

    switch importType {
    case .assets:
      loadAssetCSVData(data)
      computeCopyForwardPlatforms()

    case .cashFlows:
      loadCashFlowCSVData(data)
    }

    hasUnsavedChanges = true
  }

  /// Loads a CSV file from a URL.
  func loadFile(_ url: URL) {
    selectedFileURL = url
    guard let data = try? Data(contentsOf: url) else {
      validationErrors = [
        CSVError(
          row: 0, column: nil,
          message: String(
            localized: "Could not open file. Please check the file is a valid CSV.",
            table: "Import"))
      ]
      assetPreviewRows = []
      cashFlowPreviewRows = []
      hasUnsavedChanges = false
      return
    }
    loadCSVData(data)
  }

  // MARK: - Row Removal

  /// Removes (excludes) an asset preview row at the given index.
  func removeAssetPreviewRow(at index: Int) {
    guard index >= 0 && index < assetPreviewRows.count else { return }
    assetPreviewRows[index].isIncluded = false
    revalidate()
  }

  /// Removes (excludes) a cash flow preview row at the given index.
  func removeCashFlowPreviewRow(at index: Int) {
    guard index >= 0 && index < cashFlowPreviewRows.count else { return }
    cashFlowPreviewRows[index].isIncluded = false
    revalidate()
  }

  // MARK: - Category Resolution

  /// Resolves a category by name, reusing existing (case-insensitive) or creating new.
  func resolveCategory(name: String) -> Category? {
    modelContext.resolveCategory(name: name)
  }

  // MARK: - Queries

  /// Returns all distinct, non-empty platforms from existing assets.
  func existingPlatforms() -> [String] {
    let descriptor = FetchDescriptor<Asset>()
    let allAssets = (try? modelContext.fetch(descriptor)) ?? []

    let platforms = Set(
      allAssets
        .map { $0.platform }
        .filter { !$0.isEmpty }
    )

    return platforms.sorted()
  }

  /// Returns all existing categories.
  func existingCategories() -> [Category] {
    let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  // MARK: - Import Execution

  /// Executes the import, creating or updating a snapshot.
  ///
  /// - Returns: The created/updated Snapshot on success, or nil on failure (see `importError`).
  @discardableResult
  func executeImport() -> Snapshot? {
    importError = nil

    // Validate date
    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)
    let today = Calendar.current.startOfDay(for: Date())

    guard normalizedDate <= today else {
      importError = String(
        localized: "Snapshot date cannot be in the future.", table: "Import")
      return nil
    }

    guard !isImportDisabled else { return nil }

    // Find or create snapshot for this date
    let snapshot = findOrCreateSnapshot(date: normalizedDate)

    switch importType {
    case .assets:
      executeAssetImport(snapshot: snapshot)

    case .cashFlows:
      executeCashFlowImport(snapshot: snapshot)
    }

    hasUnsavedChanges = false
    importedSnapshot = snapshot
    return snapshot
  }

  // MARK: - Reset

  /// Clears all import state.
  func reset() {
    clearLoadedData()
    snapshotDate = Date()
    let defaultPlatform = settingsService.defaultPlatform
    selectedPlatform = defaultPlatform.isEmpty ? nil : defaultPlatform
    selectedCategory = nil
    copyForwardEnabled = true
    importError = nil
    hasUnsavedChanges = false
    importedSnapshot = nil
  }

  // MARK: - Copy-Forward Computation

  /// Computes which platforms from prior snapshots can be copied forward.
  ///
  /// Examines the most recent prior snapshot (before `snapshotDate`) and identifies
  /// platforms that are NOT present in the current import's resolved preview rows.
  func computeCopyForwardPlatforms() {
    guard importType == .assets else {
      copyForwardPlatforms = []
      return
    }

    let normalizedDate = Calendar.current.startOfDay(for: snapshotDate)

    // Find the most recent prior snapshot
    let snapshotDescriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    let allSnapshots = (try? modelContext.fetch(snapshotDescriptor)) ?? []

    let priorSnapshots =
      allSnapshots
      .filter { $0.date < normalizedDate }
      .sorted { $0.date > $1.date }

    guard let latestPrior = priorSnapshots.first else {
      copyForwardPlatforms = []
      return
    }

    let priorValues = latestPrior.assetValues ?? []

    // Collect platforms from the resolved preview rows.
    // These are the platforms that will have assets in the new snapshot.
    // The preview rows already reflect any import-level platform override
    // (applied during CSV parsing), so no separate handling is needed.
    var snapshotPlatforms = Set<String>()
    for row in assetPreviewRows where row.isIncluded {
      let platform = row.csvRow.platform
      if !platform.isEmpty {
        snapshotPlatforms.insert(platform.lowercased())
      }
    }

    // Group prior snapshot values by platform
    var platformAssets: [String: [SnapshotAssetValue]] = [:]
    for sav in priorValues {
      guard let platform = sav.asset?.platform, !platform.isEmpty else { continue }
      platformAssets[platform, default: []].append(sav)
    }

    // Build copy-forward info for platforms not already in the new snapshot
    var infos: [CopyForwardPlatformInfo] = []
    for (platform, assets) in platformAssets {
      if !snapshotPlatforms.contains(platform.lowercased()) {
        infos.append(
          CopyForwardPlatformInfo(
            platformName: platform,
            assetCount: assets.count,
            sourceSnapshotDate: latestPrior.date,
            isSelected: true
          ))
      }
    }

    copyForwardPlatforms = infos.sorted { $0.platformName < $1.platformName }
  }

  // MARK: - Private: Asset CSV Loading

  private func loadAssetCSVData(_ data: Data) {
    let result = CSVParsingService.parseAssetCSV(
      data: data, importPlatform: selectedPlatform)

    let allAssets = fetchAllAssets()
    assetPreviewRows = result.rows.map { row in
      AssetPreviewRow(
        id: UUID(),
        csvRow: row,
        isIncluded: true,
        categoryWarning: categoryWarning(for: row, existingAssets: allAssets)
      )
    }

    cashFlowPreviewRows = []

    // Separate parsing errors from duplicate errors.
    // result.errors contains both per-row parsing errors AND within-CSV duplicate errors.
    // We compute duplicates separately so we can store parsing-only errors for revalidation.
    let withinCSVDuplicates = CSVParsingService.detectAssetDuplicates(rows: result.rows)
    let duplicateMessages = Set(withinCSVDuplicates.map { $0.message })
    parsingErrors = result.errors.filter { !duplicateMessages.contains($0.message) }

    // Build full error list: parsing + within-CSV duplicates + snapshot duplicates
    let snapshotErrors = detectAssetSnapshotDuplicates(rows: result.rows)

    validationErrors = parsingErrors + withinCSVDuplicates + snapshotErrors
    validationWarnings = result.warnings
  }

  private func categoryWarning(for row: AssetCSVRow, existingAssets: [Asset]) -> String? {
    guard let selectedCategory = selectedCategory else { return nil }

    let normalizedName = row.assetName.normalizedForIdentity
    let normalizedPlatform = row.platform.normalizedForIdentity

    guard
      let existingAsset = existingAssets.first(where: {
        $0.normalizedName == normalizedName
          && $0.normalizedPlatform == normalizedPlatform
      })
    else { return nil }

    guard let existingCategory = existingAsset.category else { return nil }

    if existingCategory.name.lowercased() != selectedCategory.name.lowercased() {
      return String(
        localized:
          "This asset is currently assigned to \(existingCategory.name). Importing will reassign it to \(selectedCategory.name).",
        table: "Import")
    }

    return nil
  }

  // MARK: - Private: Cash Flow CSV Loading

  private func loadCashFlowCSVData(_ data: Data) {
    let result = CSVParsingService.parseCashFlowCSV(data: data)

    cashFlowPreviewRows = result.rows.map { row in
      CashFlowPreviewRow(
        id: UUID(),
        csvRow: row,
        isIncluded: true
      )
    }

    assetPreviewRows = []

    // Separate parsing errors from duplicate errors
    let withinCSVDuplicates = CSVParsingService.detectCashFlowDuplicates(rows: result.rows)
    let duplicateMessages = Set(withinCSVDuplicates.map { $0.message })
    parsingErrors = result.errors.filter { !duplicateMessages.contains($0.message) }

    let snapshotErrors = detectCashFlowSnapshotDuplicates(rows: result.rows)

    validationErrors = parsingErrors + withinCSVDuplicates + snapshotErrors
    validationWarnings = result.warnings
  }

}

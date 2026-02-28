//
//  BackupService.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Service for exporting and restoring full database backups as ZIP archives.
///
/// Each archive contains a `manifest.json`, 6 required CSV files covering all entities
/// and settings, and 1 optional CSV file (`exchange_rates.csv`). Uses `/usr/bin/ditto`
/// for ZIP operations (built into macOS).
@MainActor
enum BackupService {

  // MARK: - Export

  /// Exports all data to a ZIP archive at the given URL.
  ///
  /// - Parameters:
  ///   - url: Destination file URL for the `.zip` archive.
  ///   - modelContext: The model context to query data from.
  ///   - settingsService: The settings service to export settings from.
  static func exportBackup(
    to url: URL,
    modelContext: ModelContext,
    settingsService: SettingsService
  ) throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appending(path: "AssetFlowBackup-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Query all entities
    let categories = try modelContext.fetch(FetchDescriptor<Category>())
    let assets = try modelContext.fetch(FetchDescriptor<Asset>())
    let snapshots = try modelContext.fetch(FetchDescriptor<Snapshot>())
    let assetValues = try modelContext.fetch(
      FetchDescriptor<SnapshotAssetValue>())
    let cashFlows = try modelContext.fetch(
      FetchDescriptor<CashFlowOperation>())

    // Write manifest
    let manifest = BackupManifest(
      formatVersion: 3,
      exportTimestamp: ISO8601DateFormatter().string(from: Date()),
      appVersion: Constants.AppInfo.version
    )
    let manifestData = try JSONEncoder().encode(manifest)
    try manifestData.write(
      to: tempDir.appending(path: BackupCSV.manifestFileName))

    // Write CSVs
    try writeCategoriesCSV(categories, to: tempDir)
    try writeAssetsCSV(assets, to: tempDir)
    try writeSnapshotsCSV(snapshots, to: tempDir)
    try writeSnapshotAssetValuesCSV(assetValues, to: tempDir)
    try writeCashFlowOperationsCSV(cashFlows, to: tempDir)
    let exchangeRates = try modelContext.fetch(
      FetchDescriptor<ExchangeRate>())
    try writeExchangeRatesCSV(exchangeRates, to: tempDir)
    try writeSettingsCSV(settingsService: settingsService, to: tempDir)

    // ZIP via ditto
    try createZip(from: tempDir, to: url)
  }

  // MARK: - Validate

  /// Validates a backup archive without modifying any data.
  ///
  /// - Parameter url: Path to the `.zip` archive.
  /// - Returns: The parsed `BackupManifest` on success.
  /// - Throws: `BackupError` if the archive is invalid.
  static func validateBackup(at url: URL) throws -> BackupManifest {
    let tempDir = FileManager.default.temporaryDirectory
      .appending(path: "AssetFlowValidate-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try extractZip(from: url, to: tempDir)
    return try validateExtractedBackup(at: tempDir)
  }

  // MARK: - Restore

  /// Restores all data from a backup archive, replacing existing data.
  ///
  /// - Parameters:
  ///   - url: Path to the `.zip` archive.
  ///   - modelContext: The model context to restore data into.
  ///   - settingsService: The settings service to restore settings into.
  static func restoreFromBackup(
    at url: URL,
    modelContext: ModelContext,
    settingsService: SettingsService
  ) throws {
    // Extract once and validate
    let tempDir = FileManager.default.temporaryDirectory
      .appending(path: "AssetFlowRestore-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try extractZip(from: url, to: tempDir)
    _ = try validateExtractedBackup(at: tempDir)

    // Delete all existing data (reverse dependency order)
    try deleteAllData(modelContext: modelContext)

    // Parse and insert in dependency order
    let categoryIDMap = try restoreCategories(
      from: tempDir, modelContext: modelContext)
    let assetIDMap = try restoreAssets(
      from: tempDir, modelContext: modelContext,
      categoryIDMap: categoryIDMap)
    let snapshotIDMap = try restoreSnapshots(
      from: tempDir, modelContext: modelContext)
    try restoreSnapshotAssetValues(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap, assetIDMap: assetIDMap)
    try restoreCashFlowOperations(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap)
    try restoreExchangeRates(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap)
    try restoreSettings(
      from: tempDir, settingsService: settingsService)
  }
}

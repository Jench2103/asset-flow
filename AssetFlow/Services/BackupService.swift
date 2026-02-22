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
/// Each archive contains a `manifest.json` and 6 CSV files covering all entities
/// and settings. Uses `/usr/bin/ditto` for ZIP operations (built into macOS).
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

  /// Validates an already-extracted backup directory.
  ///
  /// - Parameter dir: Path to the extracted backup directory.
  /// - Returns: The parsed `BackupManifest` on success.
  /// - Throws: `BackupError` if the contents are invalid.
  private static func validateExtractedBackup(
    at dir: URL
  ) throws -> BackupManifest {
    // Validate manifest
    let manifestURL = dir.appending(path: BackupCSV.manifestFileName)
    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
      throw BackupError.missingFile(BackupCSV.manifestFileName)
    }
    let manifestData = try Data(contentsOf: manifestURL)
    let manifest: BackupManifest
    do {
      manifest = try JSONDecoder().decode(
        BackupManifest.self, from: manifestData)
    } catch {
      throw BackupError.corruptedData("Invalid manifest.json: \(error.localizedDescription)")
    }

    // Validate all CSV files exist and have correct headers
    for fileName in BackupCSV.allCSVFileNames {
      let fileURL = dir.appending(path: fileName)
      guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw BackupError.missingFile(fileName)
      }
    }

    // Categories accept both v1 (3-column) and v2 (4-column) headers
    let categoriesAcceptedHeaders: [[String]] = [
      BackupCSV.Categories.headers,
      BackupCSV.Categories.v1Headers,
    ]

    let assetsAcceptedHeaders: [[String]] = [
      BackupCSV.Assets.headers,
      BackupCSV.Assets.v2Headers,
    ]

    let cashFlowAcceptedHeaders: [[String]] = [
      BackupCSV.CashFlowOperations.headers,
      BackupCSV.CashFlowOperations.v2Headers,
    ]

    let expectedHeaders: [(String, [[String]])] = [
      (BackupCSV.Categories.fileName, categoriesAcceptedHeaders),
      (BackupCSV.Assets.fileName, assetsAcceptedHeaders),
      (BackupCSV.Snapshots.fileName, [BackupCSV.Snapshots.headers]),
      (
        BackupCSV.SnapshotAssetValues.fileName,
        [BackupCSV.SnapshotAssetValues.headers]
      ),
      (
        BackupCSV.CashFlowOperations.fileName,
        cashFlowAcceptedHeaders
      ),
      (BackupCSV.Settings.fileName, [BackupCSV.Settings.headers]),
    ]

    var parsedFiles: [String: [[String]]] = [:]

    for (fileName, acceptedHeaderSets) in expectedHeaders {
      let fileURL = dir.appending(path: fileName)
      let content = try String(contentsOf: fileURL, encoding: .utf8)
      let lines = CSVParsingService.splitCSVLines(content)
      guard let headerLine = lines.first else {
        throw BackupError.invalidCSVHeaders(
          file: fileName, expected: acceptedHeaderSets[0], got: [])
      }
      let headers = parseBackupCSVRow(headerLine)
        .map { $0.trimmingCharacters(in: .whitespaces) }
      if !acceptedHeaderSets.contains(headers) {
        throw BackupError.invalidCSVHeaders(
          file: fileName, expected: acceptedHeaderSets[0], got: headers)
      }
      // Parse data rows
      let dataRows = lines.dropFirst().map {
        parseBackupCSVRow($0)
      }
      parsedFiles[fileName] = Array(dataRows)
    }

    // Validate optional exchange_rates.csv if present
    let exchangeRatesURL = dir.appending(
      path: BackupCSV.ExchangeRates.fileName)
    if FileManager.default.fileExists(atPath: exchangeRatesURL.path) {
      let content = try String(contentsOf: exchangeRatesURL, encoding: .utf8)
      let lines = CSVParsingService.splitCSVLines(content)
      if let headerLine = lines.first {
        let headers = parseBackupCSVRow(headerLine)
          .map { $0.trimmingCharacters(in: .whitespaces) }
        if headers != BackupCSV.ExchangeRates.headers {
          throw BackupError.invalidCSVHeaders(
            file: BackupCSV.ExchangeRates.fileName,
            expected: BackupCSV.ExchangeRates.headers, got: headers)
        }
      }
    }

    // Validate foreign keys
    try validateForeignKeys(parsedFiles: parsedFiles)

    return manifest
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
      categoryIDMap: categoryIDMap,
      settingsService: settingsService)
    let snapshotIDMap = try restoreSnapshots(
      from: tempDir, modelContext: modelContext)
    try restoreSnapshotAssetValues(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap, assetIDMap: assetIDMap)
    try restoreCashFlowOperations(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap,
      settingsService: settingsService)
    try restoreExchangeRates(
      from: tempDir, modelContext: modelContext,
      snapshotIDMap: snapshotIDMap)
    try restoreSettings(
      from: tempDir, settingsService: settingsService)
  }
}

// MARK: - CSV Writing

extension BackupService {

  private static func writeCategoriesCSV(
    _ categories: [Category], to dir: URL
  ) throws {
    var lines = [BackupCSV.Categories.headers.joined(separator: ",")]
    for cat in categories {
      lines.append(
        csvLine([
          cat.id.uuidString,
          csvEscape(cat.name),
          cat.targetAllocationPercentage.map { "\($0)" } ?? "",
          "\(cat.displayOrder)",
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(path: BackupCSV.Categories.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeAssetsCSV(
    _ assets: [Asset], to dir: URL
  ) throws {
    var lines = [BackupCSV.Assets.headers.joined(separator: ",")]
    for asset in assets {
      lines.append(
        csvLine([
          asset.id.uuidString,
          csvEscape(asset.name),
          csvEscape(asset.platform),
          asset.category?.id.uuidString ?? "",
          csvEscape(asset.currency),
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(path: BackupCSV.Assets.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeSnapshotsCSV(
    _ snapshots: [Snapshot], to dir: URL
  ) throws {
    let dateFormatter = ISO8601DateFormatter()
    var lines = [BackupCSV.Snapshots.headers.joined(separator: ",")]
    for snapshot in snapshots {
      lines.append(
        csvLine([
          snapshot.id.uuidString,
          dateFormatter.string(from: snapshot.date),
          dateFormatter.string(from: snapshot.createdAt),
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(path: BackupCSV.Snapshots.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeSnapshotAssetValuesCSV(
    _ values: [SnapshotAssetValue], to dir: URL
  ) throws {
    var lines = [
      BackupCSV.SnapshotAssetValues.headers.joined(separator: ",")
    ]
    for sav in values {
      guard let snapshot = sav.snapshot, let asset = sav.asset else {
        continue
      }
      lines.append(
        csvLine([
          snapshot.id.uuidString,
          asset.id.uuidString,
          "\(sav.marketValue)",
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(
          path: BackupCSV.SnapshotAssetValues.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeCashFlowOperationsCSV(
    _ operations: [CashFlowOperation], to dir: URL
  ) throws {
    var lines = [
      BackupCSV.CashFlowOperations.headers.joined(separator: ",")
    ]
    for op in operations {
      guard let snapshot = op.snapshot else { continue }
      lines.append(
        csvLine([
          op.id.uuidString,
          snapshot.id.uuidString,
          csvEscape(op.cashFlowDescription),
          "\(op.amount)",
          csvEscape(op.currency),
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(
          path: BackupCSV.CashFlowOperations.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeExchangeRatesCSV(
    _ exchangeRates: [ExchangeRate], to dir: URL
  ) throws {
    let dateFormatter = ISO8601DateFormatter()
    var lines = [BackupCSV.ExchangeRates.headers.joined(separator: ",")]
    for er in exchangeRates {
      guard let snapshot = er.snapshot else { continue }
      // Encode ratesJSON as base64 to avoid CSV escaping issues with JSON
      let ratesBase64 = er.ratesJSON.base64EncodedString()
      lines.append(
        csvLine([
          snapshot.id.uuidString,
          csvEscape(er.baseCurrency),
          dateFormatter.string(from: er.fetchDate),
          er.isFallback ? "true" : "false",
          ratesBase64,
        ]))
    }
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(path: BackupCSV.ExchangeRates.fileName),
        atomically: true, encoding: .utf8)
  }

  private static func writeSettingsCSV(
    settingsService: SettingsService, to dir: URL
  ) throws {
    var lines = [BackupCSV.Settings.headers.joined(separator: ",")]
    lines.append(
      csvLine(["displayCurrency", csvEscape(settingsService.mainCurrency)]))
    lines.append(
      csvLine([
        "dateFormat", csvEscape(settingsService.dateFormat.rawValue),
      ]))
    lines.append(
      csvLine([
        "defaultPlatform", csvEscape(settingsService.defaultPlatform),
      ]))
    try lines.joined(separator: "\n")
      .write(
        to: dir.appending(path: BackupCSV.Settings.fileName),
        atomically: true, encoding: .utf8)
  }
}

// MARK: - CSV Helpers

extension BackupService {

  private static func csvLine(_ fields: [String]) -> String {
    fields.joined(separator: ",")
  }

  private static func csvEscape(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n")
      || value.contains("\r")
    {
      return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return value
  }
}

// MARK: - FK Validation

extension BackupService {

  private static func validateForeignKeys(
    parsedFiles: [String: [[String]]]
  ) throws {
    // Collect known IDs
    let categoryIDs = Set(
      (parsedFiles[BackupCSV.Categories.fileName] ?? [])
        .compactMap { $0.first?.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    )
    let assetIDs = Set(
      (parsedFiles[BackupCSV.Assets.fileName] ?? [])
        .compactMap { $0.first?.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    )
    let snapshotIDs = Set(
      (parsedFiles[BackupCSV.Snapshots.fileName] ?? [])
        .compactMap { $0.first?.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    )

    // Validate assets.categoryID → categories.id
    for row in parsedFiles[BackupCSV.Assets.fileName] ?? [] {
      let catID =
        row.count > 3
        ? row[3].trimmingCharacters(in: .whitespaces) : ""
      if !catID.isEmpty && !categoryIDs.contains(catID) {
        throw BackupError.invalidForeignKey(
          file: BackupCSV.Assets.fileName,
          column: "categoryID", value: catID)
      }
    }

    // Validate snapshot_asset_values.snapshotID → snapshots.id
    for row in parsedFiles[BackupCSV.SnapshotAssetValues.fileName] ?? [] {
      let snapID =
        !row.isEmpty
        ? row[0].trimmingCharacters(in: .whitespaces) : ""
      if !snapID.isEmpty && !snapshotIDs.contains(snapID) {
        throw BackupError.invalidForeignKey(
          file: BackupCSV.SnapshotAssetValues.fileName,
          column: "snapshotID", value: snapID)
      }
      let assetID =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""
      if !assetID.isEmpty && !assetIDs.contains(assetID) {
        throw BackupError.invalidForeignKey(
          file: BackupCSV.SnapshotAssetValues.fileName,
          column: "assetID", value: assetID)
      }
    }

    // Validate cash_flow_operations.snapshotID → snapshots.id
    for row in parsedFiles[BackupCSV.CashFlowOperations.fileName] ?? [] {
      let snapID =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""
      if !snapID.isEmpty && !snapshotIDs.contains(snapID) {
        throw BackupError.invalidForeignKey(
          file: BackupCSV.CashFlowOperations.fileName,
          column: "snapshotID", value: snapID)
      }
    }
  }
}

// MARK: - ZIP Operations

extension BackupService {

  private static func createZip(from dir: URL, to zipURL: URL) throws {
    // Remove existing file if present
    try? FileManager.default.removeItem(at: zipURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", "--sequesterRsrc", dir.path, zipURL.path]

    let pipe = Pipe()
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
      let errorMsg =
        String(data: errorData, encoding: .utf8) ?? "Unknown ditto error"
      throw BackupError.corruptedData("Failed to create ZIP: \(errorMsg)")
    }
  }

  private static func extractZip(from zipURL: URL, to dir: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", zipURL.path, dir.path]

    let pipe = Pipe()
    process.standardError = pipe

    do {
      try process.run()
    } catch {
      throw BackupError.invalidArchive
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw BackupError.invalidArchive
    }
  }
}

// MARK: - Restore Helpers

extension BackupService {

  private static func deleteAllData(modelContext: ModelContext) throws {
    // Fetch and delete individually (batch delete not supported with .deny rules)
    let exchangeRates = try modelContext.fetch(FetchDescriptor<ExchangeRate>())
    for item in exchangeRates { modelContext.delete(item) }

    let cashFlows = try modelContext.fetch(FetchDescriptor<CashFlowOperation>())
    for item in cashFlows { modelContext.delete(item) }

    let savs = try modelContext.fetch(FetchDescriptor<SnapshotAssetValue>())
    for item in savs { modelContext.delete(item) }

    let snapshots = try modelContext.fetch(FetchDescriptor<Snapshot>())
    for item in snapshots { modelContext.delete(item) }

    let assets = try modelContext.fetch(FetchDescriptor<Asset>())
    for item in assets { modelContext.delete(item) }

    let categories = try modelContext.fetch(FetchDescriptor<Category>())
    for item in categories { modelContext.delete(item) }
  }

  private static func readCSVRows(
    from dir: URL, fileName: String
  ) throws -> [[String]] {
    let fileURL = dir.appending(path: fileName)
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let lines = CSVParsingService.splitCSVLines(content)
    // Skip header, use RFC 4180-compliant parser that handles escaped quotes
    return Array(lines.dropFirst().map { parseBackupCSVRow($0) })
  }

  /// Parses a CSV row with proper RFC 4180 quote escaping (`""` → `"`).
  private static func parseBackupCSVRow(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    let characters = Array(line)
    var idx = 0

    while idx < characters.count {
      let char = characters[idx]
      if inQuotes {
        if char == "\"" {
          if idx + 1 < characters.count && characters[idx + 1] == "\"" {
            current.append("\"")
            idx += 2
            continue
          } else {
            inQuotes = false
          }
        } else {
          current.append(char)
        }
      } else {
        if char == "\"" {
          inQuotes = true
        } else if char == "," {
          fields.append(current)
          current = ""
        } else {
          current.append(char)
        }
      }
      idx += 1
    }
    fields.append(current)
    return fields
  }

  private static func restoreCategories(
    from dir: URL, modelContext: ModelContext
  ) throws -> [String: Category] {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.Categories.fileName)
    var idMap: [String: Category] = [:]

    for row in rows {
      let idStr = row[0].trimmingCharacters(in: .whitespaces)
      let name = row[1].trimmingCharacters(in: .whitespaces)
      let targetStr =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : ""
      let target: Decimal? =
        targetStr.isEmpty ? nil : Decimal(string: targetStr)
      let displayOrderStr =
        row.count > 3
        ? row[3].trimmingCharacters(in: .whitespaces) : "0"
      let displayOrder = Int(displayOrderStr) ?? 0

      let category = Category(
        name: name, targetAllocationPercentage: target)
      category.displayOrder = displayOrder
      if let uuid = UUID(uuidString: idStr) {
        category.id = uuid
      }
      modelContext.insert(category)
      idMap[idStr] = category
    }
    return idMap
  }

  private static func restoreAssets(
    from dir: URL,
    modelContext: ModelContext,
    categoryIDMap: [String: Category],
    settingsService: SettingsService
  ) throws -> [String: Asset] {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.Assets.fileName)
    var idMap: [String: Asset] = [:]

    for row in rows {
      let idStr = row[0].trimmingCharacters(in: .whitespaces)
      let name = row[1].trimmingCharacters(in: .whitespaces)
      let platform =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : ""
      let catIDStr =
        row.count > 3
        ? row[3].trimmingCharacters(in: .whitespaces) : ""

      let currency =
        row.count > 4
        ? row[4].trimmingCharacters(in: .whitespaces) : ""

      let asset = Asset(name: name, platform: platform)
      asset.currency =
        currency.isEmpty ? settingsService.mainCurrency : currency
      if let uuid = UUID(uuidString: idStr) {
        asset.id = uuid
      }
      if !catIDStr.isEmpty {
        asset.category = categoryIDMap[catIDStr]
      }
      modelContext.insert(asset)
      idMap[idStr] = asset
    }
    return idMap
  }

  private static func restoreSnapshots(
    from dir: URL, modelContext: ModelContext
  ) throws -> [String: Snapshot] {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.Snapshots.fileName)
    let dateFormatter = ISO8601DateFormatter()
    var idMap: [String: Snapshot] = [:]

    for row in rows {
      let idStr = row[0].trimmingCharacters(in: .whitespaces)
      let dateStr = row[1].trimmingCharacters(in: .whitespaces)
      let createdAtStr =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : ""

      guard let date = dateFormatter.date(from: dateStr) else {
        throw BackupError.corruptedData(
          "Invalid date in snapshots.csv: \(dateStr)")
      }

      let snapshot = Snapshot(date: date)
      if let uuid = UUID(uuidString: idStr) {
        snapshot.id = uuid
      }
      if let createdAt = dateFormatter.date(from: createdAtStr) {
        snapshot.createdAt = createdAt
      }
      modelContext.insert(snapshot)
      idMap[idStr] = snapshot
    }
    return idMap
  }

  private static func restoreSnapshotAssetValues(
    from dir: URL,
    modelContext: ModelContext,
    snapshotIDMap: [String: Snapshot],
    assetIDMap: [String: Asset]
  ) throws {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.SnapshotAssetValues.fileName)

    for row in rows {
      let snapIDStr = row[0].trimmingCharacters(in: .whitespaces)
      let assetIDStr =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""
      let valueStr =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : "0"

      guard let marketValue = Decimal(string: valueStr) else {
        throw BackupError.corruptedData(
          "Invalid market value: \(valueStr)")
      }

      let sav = SnapshotAssetValue(marketValue: marketValue)
      if !snapIDStr.isEmpty {
        guard let snapshot = snapshotIDMap[snapIDStr] else {
          throw BackupError.corruptedData(
            "Snapshot ID not found: \(snapIDStr)")
        }
        sav.snapshot = snapshot
      }
      if !assetIDStr.isEmpty {
        guard let asset = assetIDMap[assetIDStr] else {
          throw BackupError.corruptedData(
            "Asset ID not found: \(assetIDStr)")
        }
        sav.asset = asset
      }
      modelContext.insert(sav)
    }
  }

  private static func restoreCashFlowOperations(
    from dir: URL,
    modelContext: ModelContext,
    snapshotIDMap: [String: Snapshot],
    settingsService: SettingsService
  ) throws {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.CashFlowOperations.fileName)

    for row in rows {
      let idStr = row[0].trimmingCharacters(in: .whitespaces)
      let snapIDStr =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""
      let desc =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : ""
      let amountStr =
        row.count > 3
        ? row[3].trimmingCharacters(in: .whitespaces) : "0"

      guard let amount = Decimal(string: amountStr) else {
        throw BackupError.corruptedData(
          "Invalid amount: \(amountStr)")
      }

      let currency =
        row.count > 4
        ? row[4].trimmingCharacters(in: .whitespaces) : ""

      let op = CashFlowOperation(
        cashFlowDescription: desc, amount: amount)
      op.currency =
        currency.isEmpty ? settingsService.mainCurrency : currency
      if let uuid = UUID(uuidString: idStr) {
        op.id = uuid
      }
      if !snapIDStr.isEmpty {
        guard let snapshot = snapshotIDMap[snapIDStr] else {
          throw BackupError.corruptedData(
            "Snapshot ID not found: \(snapIDStr)")
        }
        op.snapshot = snapshot
      }
      modelContext.insert(op)
    }
  }

  private static func restoreExchangeRates(
    from dir: URL,
    modelContext: ModelContext,
    snapshotIDMap: [String: Snapshot]
  ) throws {
    let fileURL = dir.appending(path: BackupCSV.ExchangeRates.fileName)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return  // Optional file — v2 backups don't have it
    }

    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.ExchangeRates.fileName)
    let dateFormatter = ISO8601DateFormatter()

    for row in rows {
      let snapIDStr = row[0].trimmingCharacters(in: .whitespaces)
      let baseCurrency =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""
      let fetchDateStr =
        row.count > 2
        ? row[2].trimmingCharacters(in: .whitespaces) : ""
      let isFallbackStr =
        row.count > 3
        ? row[3].trimmingCharacters(in: .whitespaces) : "false"
      let ratesBase64 =
        row.count > 4
        ? row[4].trimmingCharacters(in: .whitespaces) : ""

      guard let fetchDate = dateFormatter.date(from: fetchDateStr) else {
        throw BackupError.corruptedData(
          "Invalid date in exchange_rates.csv: \(fetchDateStr)")
      }

      guard let ratesData = Data(base64Encoded: ratesBase64) else {
        throw BackupError.corruptedData(
          "Invalid base64 in exchange_rates.csv")
      }

      let exchangeRate = ExchangeRate(
        baseCurrency: baseCurrency,
        ratesJSON: ratesData,
        fetchDate: fetchDate,
        isFallback: isFallbackStr == "true")

      if !snapIDStr.isEmpty {
        guard let snapshot = snapshotIDMap[snapIDStr] else {
          throw BackupError.corruptedData(
            "Snapshot ID not found for exchange rate: \(snapIDStr)")
        }
        exchangeRate.snapshot = snapshot
      }
      modelContext.insert(exchangeRate)
    }
  }

  private static func restoreSettings(
    from dir: URL, settingsService: SettingsService
  ) throws {
    let rows = try readCSVRows(
      from: dir, fileName: BackupCSV.Settings.fileName)

    for row in rows {
      let key = row[0].trimmingCharacters(in: .whitespaces)
      let value =
        row.count > 1
        ? row[1].trimmingCharacters(in: .whitespaces) : ""

      switch key {
      case "displayCurrency":
        settingsService.mainCurrency = value

      case "dateFormat":
        if let format = DateFormatStyle(rawValue: value) {
          settingsService.dateFormat = format
        }

      case "defaultPlatform":
        settingsService.defaultPlatform = value

      default:
        break
      }
    }
  }
}

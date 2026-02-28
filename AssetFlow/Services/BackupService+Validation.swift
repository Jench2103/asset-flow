//
//  BackupService+Validation.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
//

import Foundation

// MARK: - Validation

extension BackupService {

  /// Validates an already-extracted backup directory.
  ///
  /// - Parameter dir: Path to the extracted backup directory.
  /// - Returns: The parsed `BackupManifest` on success.
  /// - Throws: `BackupError` if the contents are invalid.
  static func validateExtractedBackup(
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

// MARK: - CSV Row Parsing

extension BackupService {

  /// Parses a CSV row with proper RFC 4180 quote escaping (`""` → `"`).
  static func parseBackupCSVRow(_ line: String) -> [String] {
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
}

// MARK: - ZIP Operations

extension BackupService {

  static func createZip(from dir: URL, to zipURL: URL) throws {
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

  static func extractZip(from zipURL: URL, to dir: URL) throws {
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

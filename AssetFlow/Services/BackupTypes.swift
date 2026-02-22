//
//  BackupTypes.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation

/// Metadata stored in `manifest.json` inside a backup archive.
struct BackupManifest: Codable {
  let formatVersion: Int
  let exportTimestamp: String
  let appVersion: String
}

/// Errors that can occur during backup export, validation, or restore.
enum BackupError: LocalizedError {
  case invalidArchive
  case missingFile(String)
  case invalidCSVHeaders(file: String, expected: [String], got: [String])
  case invalidForeignKey(file: String, column: String, value: String)
  case corruptedData(String)

  var errorDescription: String? {
    switch self {
    case .invalidArchive:
      String(localized: "The file is not a valid backup archive.", table: "Services")

    case .missingFile(let name):
      String(
        localized: "Missing required file: \(name)", table: "Services")

    case .invalidCSVHeaders(let file, let expected, let got):
      String(
        localized:
          "Invalid headers in \(file). Expected: \(expected.joined(separator: ", ")). Got: \(got.joined(separator: ", ")).",
        table: "Services")

    case .invalidForeignKey(let file, let column, let value):
      String(
        localized:
          "Invalid reference in \(file): \(column) '\(value)' not found.",
        table: "Services")

    case .corruptedData(let detail):
      String(
        localized: "Corrupted data: \(detail)", table: "Services")
    }
  }
}

// MARK: - CSV Column Constants

enum BackupCSV {
  enum Categories {
    static let fileName = "categories.csv"
    static let headers = ["id", "name", "targetAllocationPercentage", "displayOrder"]
    static let v1Headers = ["id", "name", "targetAllocationPercentage"]
  }

  enum Assets {
    static let fileName = "assets.csv"
    static let headers = ["id", "name", "platform", "categoryID", "currency"]
    static let v2Headers = ["id", "name", "platform", "categoryID"]
  }

  enum Snapshots {
    static let fileName = "snapshots.csv"
    static let headers = ["id", "date", "createdAt"]
  }

  enum SnapshotAssetValues {
    static let fileName = "snapshot_asset_values.csv"
    static let headers = ["snapshotID", "assetID", "marketValue"]
  }

  enum CashFlowOperations {
    static let fileName = "cash_flow_operations.csv"
    static let headers = ["id", "snapshotID", "description", "amount", "currency"]
    static let v2Headers = ["id", "snapshotID", "description", "amount"]
  }

  enum ExchangeRates {
    static let fileName = "exchange_rates.csv"
    static let headers = ["snapshotID", "baseCurrency", "fetchDate", "isFallback", "ratesJSON"]
  }

  enum Settings {
    static let fileName = "settings.csv"
    static let headers = ["key", "value"]
  }

  static let manifestFileName = "manifest.json"

  static let allCSVFileNames = [
    Categories.fileName,
    Assets.fileName,
    Snapshots.fileName,
    SnapshotAssetValues.fileName,
    CashFlowOperations.fileName,
    Settings.fileName,
  ]

  /// CSV files required in all backup versions.
  static let requiredCSVFileNames = allCSVFileNames

  /// CSV files that are optional (may not exist in older backups).
  static let optionalCSVFileNames = [
    ExchangeRates.fileName
  ]
}

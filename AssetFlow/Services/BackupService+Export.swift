//
//  BackupService+Export.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
//

import Foundation

// MARK: - CSV Writing

extension BackupService {

  static func writeCategoriesCSV(
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

  static func writeAssetsCSV(
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

  static func writeSnapshotsCSV(
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

  static func writeSnapshotAssetValuesCSV(
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

  static func writeCashFlowOperationsCSV(
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

  static func writeExchangeRatesCSV(
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

  static func writeSettingsCSV(
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

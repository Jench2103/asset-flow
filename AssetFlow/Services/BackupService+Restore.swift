//
//  BackupService+Restore.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
//

import Foundation
import SwiftData

// MARK: - Restore Helpers

extension BackupService {

  static func deleteAllData(modelContext: ModelContext) throws {
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

  static func readCSVRows(
    from dir: URL, fileName: String
  ) throws -> [[String]] {
    let fileURL = dir.appending(path: fileName)
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let lines = CSVParsingService.splitCSVLines(content)
    // Skip header, use RFC 4180-compliant parser that handles escaped quotes
    return Array(lines.dropFirst().map { parseBackupCSVRow($0) })
  }

  static func restoreCategories(
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

  static func restoreAssets(
    from dir: URL,
    modelContext: ModelContext,
    categoryIDMap: [String: Category]
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
      asset.currency = currency
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

  static func restoreSnapshots(
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

  static func restoreSnapshotAssetValues(
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

  static func restoreCashFlowOperations(
    from dir: URL,
    modelContext: ModelContext,
    snapshotIDMap: [String: Snapshot]
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
      op.currency = currency
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

  static func restoreExchangeRates(
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

  static func restoreSettings(
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

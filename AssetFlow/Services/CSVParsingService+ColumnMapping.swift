//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

// MARK: - Column Mapping

extension CSVParsingService {

  /// Extracts header names from the first line of CSV data.
  static func extractHeaders(from data: Data) -> [String] {
    let lines = splitCSVLines(decodeCSVData(data))
    guard let headerLine = lines.first else { return [] }
    return parseCSVRow(headerLine)
  }

  /// Extracts the first N data rows (excluding header) as raw string arrays.
  static func extractSampleRows(from data: Data, count: Int = 3) -> [[String]] {
    let lines = splitCSVLines(decodeCSVData(data))
    let dataLines = Array(lines.dropFirst().prefix(count))
    return dataLines.map { parseCSVRow($0) }
  }

  /// Attempts case-insensitive auto-detection of column mapping.
  ///
  /// Returns `.matched` if all required columns for the schema are found.
  /// Returns `.needsUserMapping` with a partial map of whatever was matched
  /// if any required column is missing.
  static func autoDetectMapping(
    headers: [String],
    schema: CSVColumnSchema
  ) -> CSVAutoDetectResult {
    let normalized = headers.map {
      $0.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var columnMap: [CanonicalColumn: Int] = [:]

    for column in schema.allColumns {
      if let index = normalized.firstIndex(of: column.rawValue.lowercased()) {
        columnMap[column] = index
      }
    }

    let allRequiredFound = schema.requiredColumns.allSatisfy { columnMap[$0] != nil }

    if allRequiredFound {
      return .matched(
        CSVColumnMapping(
          schema: schema, columnMap: columnMap, rawHeaders: headers))
    } else {
      return .needsUserMapping(rawHeaders: headers, partialMap: columnMap)
    }
  }

  /// Parses asset CSV using a user-provided column mapping.
  ///
  /// Builds `AssetCSVHeaders` from the mapping and delegates to the
  /// existing row-parsing pipeline. The first line of data is skipped
  /// (assumed to be the original CSV header).
  static func parseAssetCSV(
    data: Data,
    mapping: CSVColumnMapping,
    importPlatform: String?
  ) -> CSVParseResult<AssetCSVRow> {
    let lines = splitCSVLines(decodeCSVData(data))
    guard lines.count > 1 else {
      return lines.isEmpty ? emptyFileResult() : noDataRowsResult(warnings: [])
    }

    let headers = AssetCSVHeaders(
      nameIndex: mapping.columnMap[.assetName] ?? 0,
      valueIndex: mapping.columnMap[.marketValue] ?? 1,
      platformIndex: mapping.columnMap[.platform],
      currencyIndex: mapping.columnMap[.currency],
      warnings: [])

    return parseAssetDataRows(
      lines: Array(lines.dropFirst()),
      headers: headers, importPlatform: importPlatform)
  }

  /// Parses cash flow CSV using a user-provided column mapping.
  static func parseCashFlowCSV(
    data: Data,
    mapping: CSVColumnMapping
  ) -> CSVParseResult<CashFlowCSVRow> {
    let lines = splitCSVLines(decodeCSVData(data))
    guard lines.count > 1 else {
      return lines.isEmpty ? emptyFileResult() : noDataRowsResult(warnings: [])
    }

    let headers = CashFlowCSVHeaders(
      descIndex: mapping.columnMap[.description] ?? 0,
      amountIndex: mapping.columnMap[.amount] ?? 1,
      currencyIndex: mapping.columnMap[.currency],
      warnings: [])

    return parseCashFlowDataRows(
      lines: Array(lines.dropFirst()), headers: headers)
  }
}

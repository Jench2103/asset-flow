//
//  CSVParsingService.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation

/// CSV parsing service for asset and cash flow imports.
///
/// Handles parsing, validation, and duplicate detection per SPEC Sections 4.2-4.6.
/// Takes raw `Data` as input -- file I/O is the caller's responsibility.
///
/// Duplicate detection between CSV and existing snapshot data is NOT handled here;
/// it requires ModelContext access and will be performed by the Import ViewModel.
enum CSVParsingService {

  // MARK: - Asset CSV Parsing

  /// Parses asset CSV data.
  ///
  /// - Parameters:
  ///   - data: Raw CSV file data (UTF-8, BOM-tolerant).
  ///   - importPlatform: Optional import-level platform override.
  /// - Returns: Parse result with rows, errors, and warnings.
  static func parseAssetCSV(
    data: Data,
    importPlatform: String?
  ) -> CSVParseResult<AssetCSVRow> {
    let lines = splitCSVLines(decodeCSVData(data))

    guard let headerLine = lines.first else {
      return emptyFileResult()
    }

    let validated = validateAssetHeaders(parseCSVRow(headerLine))

    switch validated {
    case .failure(let validationError):
      return CSVParseResult(rows: [], errors: validationError.errors, warnings: [])

    case .success(let hdr):
      return parseAssetDataRows(
        lines: Array(lines.dropFirst()),
        headers: hdr, importPlatform: importPlatform)
    }
  }

  // MARK: - Cash Flow CSV Parsing

  /// Parses cash flow CSV data.
  ///
  /// - Parameter data: Raw CSV file data (UTF-8, BOM-tolerant).
  /// - Returns: Parse result with rows, errors, and warnings.
  static func parseCashFlowCSV(
    data: Data
  ) -> CSVParseResult<CashFlowCSVRow> {
    let lines = splitCSVLines(decodeCSVData(data))

    guard let headerLine = lines.first else {
      return emptyFileResult()
    }

    let validated = validateCashFlowHeaders(parseCSVRow(headerLine))

    switch validated {
    case .failure(let validationError):
      return CSVParseResult(rows: [], errors: validationError.errors, warnings: [])

    case .success(let hdr):
      return parseCashFlowDataRows(
        lines: Array(lines.dropFirst()), headers: hdr)
    }
  }
}

// MARK: - Header Validation

extension CSVParsingService {

  private static func validateAssetHeaders(
    _ headers: [String]
  ) -> Result<AssetCSVHeaders, CSVHeaderValidationError> {
    let normalized = headers.map {
      $0.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var errors: [CSVError] = []
    let nameIndex = normalized.firstIndex(of: "asset name")
    let valueIndex = normalized.firstIndex(of: "market value")

    if nameIndex == nil {
      errors.append(
        CSVError(
          row: 1, column: "Asset Name",
          message: "Missing required column: Asset Name"))
    }
    if valueIndex == nil {
      errors.append(
        CSVError(
          row: 1, column: "Market Value",
          message: "Missing required column: Market Value"))
    }

    guard errors.isEmpty, let nameIndex, let valueIndex else {
      return .failure(CSVHeaderValidationError(errors: errors))
    }

    let knownColumns: Set<String> = [
      "asset name", "market value", "platform", "currency",
    ]

    return .success(
      AssetCSVHeaders(
        nameIndex: nameIndex,
        valueIndex: valueIndex,
        platformIndex: normalized.firstIndex(of: "platform"),
        currencyIndex: normalized.firstIndex(of: "currency"),
        warnings: unrecognizedColumnWarnings(
          headers: headers, normalized: normalized,
          knownColumns: knownColumns)))
  }

  private static func validateCashFlowHeaders(
    _ headers: [String]
  ) -> Result<CashFlowCSVHeaders, CSVHeaderValidationError> {
    let normalized = headers.map {
      $0.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var errors: [CSVError] = []
    let descIndex = normalized.firstIndex(of: "description")
    let amountIndex = normalized.firstIndex(of: "amount")

    if descIndex == nil {
      errors.append(
        CSVError(
          row: 1, column: "Description",
          message: "Missing required column: Description"))
    }
    if amountIndex == nil {
      errors.append(
        CSVError(
          row: 1, column: "Amount",
          message: "Missing required column: Amount"))
    }

    guard errors.isEmpty, let descIndex, let amountIndex else {
      return .failure(CSVHeaderValidationError(errors: errors))
    }

    let knownColumns: Set<String> = ["description", "amount", "currency"]

    return .success(
      CashFlowCSVHeaders(
        descIndex: descIndex,
        amountIndex: amountIndex,
        currencyIndex: normalized.firstIndex(of: "currency"),
        warnings: unrecognizedColumnWarnings(
          headers: headers, normalized: normalized,
          knownColumns: knownColumns)))
  }

  private static func unrecognizedColumnWarnings(
    headers: [String],
    normalized: [String],
    knownColumns: Set<String>
  ) -> [CSVWarning] {
    var warnings: [CSVWarning] = []
    for (idx, header) in normalized.enumerated()
    where !knownColumns.contains(header) {
      warnings.append(
        CSVWarning(
          row: 1, column: headers[idx],
          message: "Unrecognized column: \(headers[idx]) (will be ignored)"))
    }
    return warnings
  }
}

// MARK: - Data Row Parsing

extension CSVParsingService {

  private static func parseAssetDataRows(
    lines: [String],
    headers: AssetCSVHeaders,
    importPlatform: String?
  ) -> CSVParseResult<AssetCSVRow> {
    if lines.isEmpty {
      return noDataRowsResult(warnings: headers.warnings)
    }

    var rows: [AssetCSVRow] = []
    var errors: [CSVError] = []
    var warnings = headers.warnings

    for (lineIndex, line) in lines.enumerated() {
      let fields = parseCSVRow(line)
      if isEmptyRow(fields) { continue }

      switch parseAssetRow(
        fields: fields, rowNumber: lineIndex + 2,
        headers: headers, importPlatform: importPlatform)
      {
      case .error(let err):
        errors.append(err)

      case .row(let row, let rowWarnings):
        rows.append(row)
        warnings.append(contentsOf: rowWarnings)
      }
    }

    errors.append(contentsOf: detectAssetDuplicates(rows: rows))
    return CSVParseResult(
      rows: rows, errors: errors, warnings: warnings)
  }

  private static func parseCashFlowDataRows(
    lines: [String],
    headers: CashFlowCSVHeaders
  ) -> CSVParseResult<CashFlowCSVRow> {
    if lines.isEmpty {
      return noDataRowsResult(warnings: headers.warnings)
    }

    var rows: [CashFlowCSVRow] = []
    var errors: [CSVError] = []
    var warnings = headers.warnings

    for (lineIndex, line) in lines.enumerated() {
      let fields = parseCSVRow(line)
      if isEmptyRow(fields) { continue }

      switch parseCashFlowRow(
        fields: fields, rowNumber: lineIndex + 2,
        headers: headers)
      {
      case .error(let err):
        errors.append(err)

      case .row(let row, let rowWarnings):
        rows.append(row)
        warnings.append(contentsOf: rowWarnings)
      }
    }

    errors.append(
      contentsOf: detectCashFlowDuplicates(rows: rows))
    return CSVParseResult(
      rows: rows, errors: errors, warnings: warnings)
  }
}

// MARK: - Single Row Parsing

extension CSVParsingService {

  private static func parseAssetRow(
    fields: [String],
    rowNumber: Int,
    headers: AssetCSVHeaders,
    importPlatform: String?
  ) -> RowParseResult<AssetCSVRow> {
    let name = fieldValue(fields: fields, index: headers.nameIndex)
    if name.isEmpty {
      return .error(
        CSVError(
          row: rowNumber, column: "Asset Name",
          message: "Asset name is empty."))
    }

    let raw = fieldValue(fields: fields, index: headers.valueIndex)
    guard let marketValue = parseDecimalValue(raw) else {
      return .error(
        CSVError(
          row: rowNumber, column: "Market Value",
          message: "Cannot parse '\(raw)' as a number."))
    }

    let platform = resolveAssetPlatform(
      fields: fields, headers: headers,
      importPlatform: importPlatform)

    let currency =
      headers.currencyIndex.map {
        fieldValue(fields: fields, index: $0)
      } ?? ""

    return .row(
      AssetCSVRow(
        assetName: name, marketValue: marketValue,
        platform: platform, currency: currency),
      marketValueWarnings(
        value: marketValue, name: name,
        rowNumber: rowNumber))
  }

  private static func parseCashFlowRow(
    fields: [String],
    rowNumber: Int,
    headers: CashFlowCSVHeaders
  ) -> RowParseResult<CashFlowCSVRow> {
    let desc = fieldValue(
      fields: fields, index: headers.descIndex)
    if desc.isEmpty {
      return .error(
        CSVError(
          row: rowNumber, column: "Description",
          message: "Description is empty."))
    }

    let raw = fieldValue(
      fields: fields, index: headers.amountIndex)
    guard let amount = parseDecimalValue(raw) else {
      return .error(
        CSVError(
          row: rowNumber, column: "Amount",
          message: "Cannot parse '\(raw)' as a number."))
    }

    var warnings: [CSVWarning] = []
    if amount == 0 {
      warnings.append(
        CSVWarning(
          row: rowNumber, column: "Amount",
          message: "Amount is zero for '\(desc)'."))
    }

    let currency =
      headers.currencyIndex.map {
        fieldValue(fields: fields, index: $0)
      } ?? ""

    return .row(
      CashFlowCSVRow(description: desc, amount: amount, currency: currency),
      warnings)
  }

  private static func resolveAssetPlatform(
    fields: [String],
    headers: AssetCSVHeaders,
    importPlatform: String?
  ) -> String {
    if let importPlatform = importPlatform {
      return importPlatform
    } else if let idx = headers.platformIndex {
      return fieldValue(fields: fields, index: idx)
    }
    return ""
  }

  private static func marketValueWarnings(
    value: Decimal, name: String, rowNumber: Int
  ) -> [CSVWarning] {
    let col = "Market Value"
    if value == 0 {
      let msg = "Market value is zero for '\(name)'."
      return [CSVWarning(row: rowNumber, column: col, message: msg)]
    } else if value < 0 {
      let msg = "Market value is negative for '\(name)'."
      return [CSVWarning(row: rowNumber, column: col, message: msg)]
    }
    return []
  }
}

// MARK: - Private Helpers

extension CSVParsingService {

  private static func fieldValue(
    fields: [String], index: Int
  ) -> String {
    guard index < fields.count else { return "" }
    return fields[index].trimmingCharacters(in: .whitespaces)
  }

  private static func isEmptyRow(_ fields: [String]) -> Bool {
    fields.allSatisfy {
      $0.trimmingCharacters(in: .whitespaces).isEmpty
    }
  }

  private static func emptyFileResult<T>() -> CSVParseResult<T> {
    let err = CSVError(
      row: 0, column: nil,
      message: "File is empty or contains no data.")
    return CSVParseResult(rows: [], errors: [err], warnings: [])
  }

  private static func noDataRowsResult<T>(
    warnings: [CSVWarning]
  ) -> CSVParseResult<T> {
    let err = CSVError(
      row: 0, column: nil,
      message: "File contains no data rows.")
    return CSVParseResult(
      rows: [], errors: [err], warnings: warnings)
  }

  static func decodeCSVData(_ data: Data) -> String {
    var data = data
    let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    if data.count >= 3 && Array(data.prefix(3)) == bom {
      data = data.dropFirst(3)
    }
    return String(data: data, encoding: .utf8) ?? ""
  }

  static func splitCSVLines(_ text: String) -> [String] {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
  }

  static func parseCSVRow(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    for char in line {
      if char == "\"" {
        inQuotes.toggle()
      } else if char == "," && !inQuotes {
        fields.append(current)
        current = ""
      } else {
        current.append(char)
      }
    }
    fields.append(current)
    return fields
  }

  static func parseDecimalValue(_ raw: String) -> Decimal? {
    var cleaned = raw.trimmingCharacters(in: .whitespaces)
    let currencySymbols: Set<Character> = [
      "$", "€", "£", "¥", "₩", "₹",
    ]
    cleaned = String(
      cleaned.filter { !currencySymbols.contains($0) })
    cleaned = cleaned.replacingOccurrences(of: ",", with: "")
    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
    guard !cleaned.isEmpty else { return nil }
    return Decimal(string: cleaned)
  }

  static func detectAssetDuplicates(
    rows: [AssetCSVRow]
  ) -> [CSVError] {
    var seen: [String: Int] = [:]
    var errors: [CSVError] = []
    for (index, row) in rows.enumerated() {
      let identity = normalizedAssetIdentity(row: row)
      let rowNumber = index + 2
      if let firstRow = seen[identity] {
        errors.append(
          CSVError(
            row: rowNumber, column: nil,
            message:
              "Duplicate asset '\(row.assetName)' (platform: '\(row.platform)') — first appeared in row \(firstRow)."
          ))
      } else {
        seen[identity] = rowNumber
      }
    }
    return errors
  }

  static func detectCashFlowDuplicates(
    rows: [CashFlowCSVRow]
  ) -> [CSVError] {
    var seen: [String: Int] = [:]
    var errors: [CSVError] = []
    for (index, row) in rows.enumerated() {
      let normalized = row.description.lowercased()
        .trimmingCharacters(in: .whitespaces)
      let rowNumber = index + 2
      if let firstRow = seen[normalized] {
        errors.append(
          CSVError(
            row: rowNumber, column: nil,
            message:
              "Duplicate description '\(row.description)' — first appeared in row \(firstRow)."
          ))
      } else {
        seen[normalized] = rowNumber
      }
    }
    return errors
  }

  private static func normalizedAssetIdentity(
    row: AssetCSVRow
  ) -> String {
    let name = row.assetName
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(
        of: "\\s+", with: " ", options: .regularExpression
      )
      .lowercased()
    let platform = row.platform
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(
        of: "\\s+", with: " ", options: .regularExpression
      )
      .lowercased()
    return "\(name)|\(platform)"
  }
}

//
//  CSVParsingTypes.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation

/// A parsed row from an asset CSV import.
struct AssetCSVRow {
  let assetName: String
  let marketValue: Decimal
  let platform: String
}

/// A parsed row from a cash flow CSV import.
struct CashFlowCSVRow {
  let description: String
  let amount: Decimal
}

/// A CSV parsing error with row and column context.
struct CSVError: Error, Equatable {
  let row: Int
  let column: String?
  let message: String
}

/// A CSV parsing warning with row and column context.
struct CSVWarning: Equatable {
  let row: Int
  let column: String?
  let message: String
}

/// Result of parsing a CSV file.
struct CSVParseResult<T> {
  let rows: [T]
  let errors: [CSVError]
  let warnings: [CSVWarning]

  var hasErrors: Bool { !errors.isEmpty }
  var isValid: Bool { errors.isEmpty }
}

/// Validated header indices for asset CSV parsing.
struct AssetCSVHeaders {
  let nameIndex: Int
  let valueIndex: Int
  let platformIndex: Int?
  let warnings: [CSVWarning]
}

/// Validated header indices for cash flow CSV parsing.
struct CashFlowCSVHeaders {
  let descIndex: Int
  let amountIndex: Int
  let warnings: [CSVWarning]
}

/// Result of parsing a single CSV data row.
enum RowParseResult<T> {
  case row(T, [CSVWarning])
  case error(CSVError)
}

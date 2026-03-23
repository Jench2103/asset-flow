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

/// Result of a CSV import operation in bulk entry.
struct CSVImportResult {
  let matchedCount: Int
  let newCount: Int
  let errors: [String]
  let parserWarnings: [String]
  let platformMismatches: [String]
  let currencyMismatches: [String]

  var totalImported: Int { matchedCount + newCount }
  var hasErrors: Bool { !errors.isEmpty }
  var hasWarnings: Bool {
    !parserWarnings.isEmpty || !platformMismatches.isEmpty || !currencyMismatches.isEmpty
  }

  /// Formats the import result into a user-facing title and message.
  func formattedResult() -> (title: String, message: String) {
    let title: String
    if hasErrors {
      title = String(localized: "Import Error", table: "Snapshot")
    } else if hasWarnings {
      title = String(localized: "Import Warning", table: "Snapshot")
    } else {
      title = String(localized: "CSV Import", table: "Snapshot")
    }

    var lines: [String] = []

    if matchedCount > 0 {
      lines.append(
        String(
          localized: "\(matchedCount) existing assets updated.",
          table: "Snapshot"))
    }
    if newCount > 0 {
      lines.append(
        String(
          localized: "\(newCount) new assets added.",
          table: "Snapshot"))
    }
    if totalImported == 0 && !hasErrors {
      lines.append(
        String(
          localized: "No assets were imported.",
          table: "Snapshot"))
    }

    for error in errors {
      lines.append(error)
    }
    for warning in parserWarnings {
      lines.append(warning)
    }

    if !platformMismatches.isEmpty {
      let names = platformMismatches.joined(separator: ", ")
      lines.append(
        String(
          localized:
            "\(platformMismatches.count) assets skipped (platform mismatch): \(names)",
          table: "Snapshot"))
    }
    if !currencyMismatches.isEmpty {
      let names = currencyMismatches.joined(separator: ", ")
      lines.append(
        String(
          localized:
            "\(currencyMismatches.count) assets skipped (currency mismatch): \(names)",
          table: "Snapshot"))
    }

    return (title: title, message: lines.joined(separator: "\n\n"))
  }
}

/// Source of a bulk entry row's value.
enum ValueSource {
  case manual
  case csv
  case manualNew
}

/// A single row in the bulk entry table, representing one asset to update.
struct BulkEntryRow: Identifiable {
  let id: UUID
  let asset: Asset?
  var assetName: String
  let platform: String
  var currency: String
  let previousValue: Decimal?
  var newValueText: String
  var isIncluded: Bool
  var source: ValueSource
  var categoryName: String?

  var newValue: Decimal? { Decimal(string: newValueText) }
  var isUpdated: Bool { isIncluded && newValue != nil && !hasZeroValueError }
  var isPending: Bool { isIncluded && (newValueText.isEmpty || newValue == nil) }
  var hasValidationError: Bool { !newValueText.isEmpty && newValue == nil }
  var hasZeroValueError: Bool { isIncluded && newValue == Decimal(0) }
  var isNewRow: Bool { source == .manualNew }
  var hasEmptyName: Bool { isNewRow && assetName.trimmingCharacters(in: .whitespaces).isEmpty }
  var isNewAsset: Bool { asset == nil }
}

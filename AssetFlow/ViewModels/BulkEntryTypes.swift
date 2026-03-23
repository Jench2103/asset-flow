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

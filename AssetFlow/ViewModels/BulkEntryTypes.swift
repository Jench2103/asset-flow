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
  let warnings: [String]

  var totalImported: Int { matchedCount + newCount }
  var hasIssues: Bool { !errors.isEmpty || !warnings.isEmpty }
}

/// Source of a bulk entry row's value.
enum ValueSource {
  case manual
  case csv
}

/// A single row in the bulk entry table, representing one asset to update.
struct BulkEntryRow: Identifiable {
  let id: UUID
  let asset: Asset?
  let assetName: String
  let platform: String
  let currency: String
  let previousValue: Decimal?
  var newValueText: String
  var isIncluded: Bool
  var source: ValueSource
  var csvCategory: String?

  var newValue: Decimal? { Decimal(string: newValueText) }
  var isUpdated: Bool { isIncluded && newValue != nil && !hasZeroValueError }
  var isPending: Bool { isIncluded && (newValueText.isEmpty || newValue == nil) }
  var hasValidationError: Bool { !newValueText.isEmpty && newValue == nil }
  var hasZeroValueError: Bool { isIncluded && newValue == Decimal(0) }
}

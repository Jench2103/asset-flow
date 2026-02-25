//
//  ImportTypes.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation

/// Import type selector: Assets or Cash Flows.
enum ImportType: String, CaseIterable {
  case assets
  case cashFlows
}

/// How the import-level platform is applied to CSV rows.
enum PlatformApplyMode: String, CaseIterable {
  /// Override all rows with the selected platform.
  case overrideAll
  /// Only fill rows that have no platform in the CSV.
  case fillEmptyOnly
}

/// How the import-level category is applied to CSV rows.
enum CategoryApplyMode: String, CaseIterable {
  /// Override all rows with the selected category.
  case overrideAll
  /// Only fill rows whose existing asset has no category.
  case fillEmptyOnly
}

/// A preview row for an asset CSV import, with inclusion state and category warning.
struct AssetPreviewRow: Identifiable {
  let id: UUID
  let csvRow: AssetCSVRow
  var isIncluded: Bool
  var categoryWarning: String?
  var currencyWarning: String?
  var currencyError: String?
  var effectiveCurrency: String
  var effectiveCategory: String
  var duplicateError: String?
  var snapshotDuplicateError: String?
  var marketValueWarning: String?
}

/// A preview row for a cash flow CSV import, with inclusion state.
struct CashFlowPreviewRow: Identifiable {
  let id: UUID
  let csvRow: CashFlowCSVRow
  var isIncluded: Bool
  var duplicateError: String?
  var snapshotDuplicateError: String?
  var amountWarning: String?
}

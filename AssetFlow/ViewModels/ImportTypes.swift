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

/// A preview row for an asset CSV import, with inclusion state and category warning.
struct AssetPreviewRow: Identifiable {
  let id: UUID
  let csvRow: AssetCSVRow
  var isIncluded: Bool
  var categoryWarning: String?
}

/// A preview row for a cash flow CSV import, with inclusion state.
struct CashFlowPreviewRow: Identifiable {
  let id: UUID
  let csvRow: CashFlowCSVRow
  var isIncluded: Bool
}

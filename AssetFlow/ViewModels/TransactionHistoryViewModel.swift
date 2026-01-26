//
//  TransactionHistoryViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/1/26.
//

import Foundation
import Observation

/// ViewModel for displaying a chronological list of transactions for an asset.
///
/// Provides sorted transactions (newest first) and a transaction count.
@Observable
@MainActor
class TransactionHistoryViewModel {
  let asset: Asset

  // MARK: - Computed Properties

  /// Transactions sorted by date, newest first
  var sortedTransactions: [Transaction] {
    (asset.transactions ?? []).sorted(by: { $0.transactionDate > $1.transactionDate })
  }

  /// Number of transactions for this asset
  var transactionCount: Int {
    asset.transactions?.count ?? 0
  }

  // MARK: - Initializer

  init(asset: Asset) {
    self.asset = asset
  }
}

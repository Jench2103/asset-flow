//
//  Snapshot.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData

@Model
final class Snapshot {
  #Unique<Snapshot>([\.date])

  var id: UUID
  var date: Date
  var createdAt: Date

  @Relationship(deleteRule: .cascade, inverse: \SnapshotAssetValue.snapshot)
  var assetValues: [SnapshotAssetValue]?

  @Relationship(deleteRule: .cascade, inverse: \CashFlowOperation.snapshot)
  var cashFlowOperations: [CashFlowOperation]?

  @Relationship(deleteRule: .cascade, inverse: \ExchangeRate.snapshot)
  var exchangeRate: ExchangeRate?

  init(date: Date) {
    self.id = UUID()
    self.date = Calendar.current.startOfDay(for: date)
    self.createdAt = Date()
    self.assetValues = []
    self.cashFlowOperations = []
  }
}

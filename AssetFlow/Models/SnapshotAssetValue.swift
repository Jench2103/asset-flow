//
//  SnapshotAssetValue.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData

@Model
final class SnapshotAssetValue {
  var marketValue: Decimal

  @Relationship
  var snapshot: Snapshot?

  @Relationship
  var asset: Asset?

  init(marketValue: Decimal) {
    self.marketValue = marketValue
    self.snapshot = nil
    self.asset = nil
  }
}

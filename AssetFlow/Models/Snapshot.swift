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

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
final class SnapshotAssetValue {
  #Unique<SnapshotAssetValue>([\.snapshot, \.asset])

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

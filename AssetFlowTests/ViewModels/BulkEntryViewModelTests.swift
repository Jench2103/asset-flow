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
import Testing

@testable import AssetFlow

@Suite("BulkEntryRow Tests")
@MainActor
struct BulkEntryRowTests {

  @Test("isUpdated is true when included and has valid decimal value")
  func isUpdatedWithValidValue() {
    var row = makeBulkEntryRow()
    row.newValueText = "1234.56"
    row.isIncluded = true
    #expect(row.isUpdated == true)
    #expect(row.isPending == false)
    #expect(row.hasValidationError == false)
  }

  @Test("isPending is true when included and value text is empty")
  func isPendingWhenEmpty() {
    var row = makeBulkEntryRow()
    row.newValueText = ""
    row.isIncluded = true
    #expect(row.isPending == true)
    #expect(row.isUpdated == false)
  }

  @Test("hasValidationError is true when text is non-empty but not a valid decimal")
  func hasValidationErrorWithInvalidText() {
    var row = makeBulkEntryRow()
    row.newValueText = "abc"
    row.isIncluded = true
    #expect(row.hasValidationError == true)
    #expect(row.isPending == true)
    #expect(row.isUpdated == false)
  }

  @Test("excluded row is neither updated nor pending")
  func excludedRowState() {
    var row = makeBulkEntryRow()
    row.newValueText = "100"
    row.isIncluded = false
    #expect(row.isUpdated == false)
    #expect(row.isPending == false)
  }

  @Test("newValue parses valid decimal string")
  func newValueParsesDecimal() {
    var row = makeBulkEntryRow()
    row.newValueText = "42.50"
    #expect(row.newValue == Decimal(string: "42.50"))
  }

  @Test("newValue returns nil for invalid string")
  func newValueReturnsNilForInvalid() {
    var row = makeBulkEntryRow()
    row.newValueText = "not-a-number"
    #expect(row.newValue == nil)
  }

  // MARK: - Helpers

  private func makeBulkEntryRow(
    asset: Asset? = nil,
    assetName: String = "Test Asset",
    platform: String = "Test Platform",
    currency: String = "USD",
    previousValue: Decimal? = Decimal(100)
  ) -> BulkEntryRow {
    BulkEntryRow(
      id: UUID(),
      asset: asset,
      assetName: assetName,
      platform: platform,
      currency: currency,
      previousValue: previousValue,
      newValueText: "",
      isIncluded: true,
      source: .manual,
      csvCategory: nil
    )
  }
}

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
import Testing

@testable import AssetFlow

@Suite("CSV Parsing Currency Tests")
@MainActor
struct CSVParsingCurrencyTests {

  // MARK: - Asset CSV Currency Tests

  @Test("Parse asset CSV with currency column")
  func parseAssetCSVWithCurrencyColumn() {
    let csv = """
      Asset Name,Market Value,Platform,Currency
      AAPL,15000,Schwab,USD
      TSMC,500000,Fubon,TWD
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseAssetCSV(
      data: data, importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows.count == 2)
    #expect(result.rows[0].currency == "USD")
    #expect(result.rows[1].currency == "TWD")
  }

  @Test("Parse asset CSV without currency column defaults to empty string")
  func parseAssetCSVWithoutCurrencyColumn() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Schwab
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseAssetCSV(
      data: data, importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows.count == 1)
    #expect(result.rows[0].currency == "")
  }

  @Test("Currency column is recognized and does not produce warning")
  func currencyColumnRecognizedInAssets() {
    let csv = """
      Asset Name,Market Value,Currency
      AAPL,15000,USD
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseAssetCSV(
      data: data, importPlatform: nil)

    #expect(result.isValid)
    // "Currency" should be a known column — no "unrecognized column" warning
    #expect(!result.warnings.contains(where: { $0.column == "Currency" }))
  }

  // MARK: - Cash Flow CSV Currency Tests

  @Test("Parse cash flow CSV with currency column")
  func parseCashFlowCSVWithCurrencyColumn() {
    let csv = """
      Description,Amount,Currency
      Salary,50000,TWD
      Dividend,100,USD
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseCashFlowCSV(data: data)

    #expect(result.isValid)
    #expect(result.rows.count == 2)
    #expect(result.rows[0].currency == "TWD")
    #expect(result.rows[1].currency == "USD")
  }

  @Test("Parse cash flow CSV without currency column defaults to empty string")
  func parseCashFlowCSVWithoutCurrencyColumn() {
    let csv = """
      Description,Amount
      Salary,50000
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseCashFlowCSV(data: data)

    #expect(result.isValid)
    #expect(result.rows.count == 1)
    #expect(result.rows[0].currency == "")
  }

  @Test("Currency column is recognized in cash flow CSV")
  func currencyColumnRecognizedInCashFlows() {
    let csv = """
      Description,Amount,Currency
      Salary,50000,TWD
      """
    let data = Data(csv.utf8)
    let result = CSVParsingService.parseCashFlowCSV(data: data)

    #expect(result.isValid)
    #expect(!result.warnings.contains(where: { $0.column == "Currency" }))
  }
}

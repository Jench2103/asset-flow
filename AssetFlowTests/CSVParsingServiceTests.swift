//
//  CSVParsingServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("CSVParsingService Tests")
@MainActor
struct CSVParsingServiceTests {

  // MARK: - Helpers

  private func csvData(_ string: String) -> Data {
    string.data(using: .utf8)!
  }

  // MARK: - Asset CSV: Valid Parsing

  @Test("Valid asset CSV parses correctly")
  func testValidAssetCSV() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Interactive Brokers
      VTI,28000,Interactive Brokers
      Bitcoin,5000,Coinbase
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows.count == 3)
    #expect(result.rows[0].assetName == "AAPL")
    #expect(result.rows[0].marketValue == Decimal(15000))
    #expect(result.rows[0].platform == "Interactive Brokers")
    #expect(result.rows[2].assetName == "Bitcoin")
    #expect(result.rows[2].platform == "Coinbase")
  }

  @Test("Asset CSV without platform column")
  func testAssetCSVWithoutPlatformColumn() {
    let csv = """
      Asset Name,Market Value
      AAPL,15000
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows[0].platform == "")
  }

  // MARK: - Asset CSV: Missing Required Columns

  @Test("Missing Asset Name column returns error")
  func testMissingAssetNameColumn() {
    let csv = """
      Market Value,Platform
      15000,Firstrade
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Asset Name"))
  }

  @Test("Missing Market Value column returns error")
  func testMissingMarketValueColumn() {
    let csv = """
      Asset Name,Platform
      AAPL,Firstrade
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Market Value"))
  }

  @Test("Missing both Asset Name and Market Value columns reports 2 errors")
  func testMissingBothAssetColumns() {
    let csv = """
      Platform,Extra
      Firstrade,ignored
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors.count == 2)
    #expect(result.errors.contains(where: { $0.message.contains("Asset Name") }))
    #expect(result.errors.contains(where: { $0.message.contains("Market Value") }))
  }

  // MARK: - Asset CSV: Row Validation

  @Test("Empty asset name returns error")
  func testEmptyAssetName() {
    let csv = """
      Asset Name,Market Value
      ,15000
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("empty"))
  }

  @Test("Unparseable market value returns error")
  func testUnparseableMarketValue() {
    let csv = """
      Asset Name,Market Value
      AAPL,abc
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Cannot parse"))
  }

  @Test("Empty file returns error")
  func testEmptyFile() {
    let result = CSVParsingService.parseAssetCSV(data: csvData(""), importPlatform: nil)

    #expect(result.hasErrors)
  }

  @Test("Header only returns error")
  func testHeaderOnlyFile() {
    let csv = "Asset Name,Market Value\n"
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("no data"))
  }

  // MARK: - Asset CSV: Platform Handling (SPEC 4.5)

  @Test("Import-level platform overrides CSV column")
  func testImportPlatformOverrides() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Some Other Broker
      """
    let result = CSVParsingService.parseAssetCSV(
      data: csvData(csv), importPlatform: "Firstrade")

    #expect(result.rows[0].platform == "Firstrade")
  }

  @Test("No platform column and no import platform gives empty platform")
  func testNoPlatformAtAll() {
    let csv = """
      Asset Name,Market Value
      AAPL,15000
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.rows[0].platform == "")
  }

  // MARK: - Asset CSV: Warnings

  @Test("Zero market value generates warning")
  func testZeroMarketValueWarning() {
    let csv = """
      Asset Name,Market Value
      AAPL,0
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.warnings.contains(where: { $0.message.contains("zero") }))
  }

  @Test("Negative market value generates warning")
  func testNegativeMarketValueWarning() {
    let csv = """
      Asset Name,Market Value
      AAPL,-500
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.warnings.contains(where: { $0.message.contains("negative") }))
  }

  @Test("Unrecognized columns generate warning")
  func testUnrecognizedColumnsWarning() {
    let csv = """
      Asset Name,Market Value,Extra Column
      AAPL,15000,ignored
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.warnings.contains(where: { $0.column == "Extra Column" }))
  }

  // MARK: - Asset CSV: Duplicate Detection (SPEC 4.6)

  @Test("Duplicate assets within CSV returns error")
  func testDuplicateAssetsInCSV() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Firstrade
      AAPL,16000,Firstrade
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors.contains(where: { $0.message.contains("Duplicate") }))
  }

  @Test("Same asset name on different platforms is not a duplicate")
  func testSameNameDifferentPlatformNotDuplicate() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Firstrade
      AAPL,16000,Schwab
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows.count == 2)
  }

  @Test("Case-insensitive duplicate detection")
  func testCaseInsensitiveDuplicateDetection() {
    let csv = """
      Asset Name,Market Value,Platform
      AAPL,15000,Firstrade
      aapl,16000,firstrade
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.hasErrors)
    #expect(result.errors.contains(where: { $0.message.contains("Duplicate") }))
  }

  // MARK: - Asset CSV: Number Parsing

  @Test("BOM tolerance")
  func testBOMTolerance() {
    let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
    let csvString = "Asset Name,Market Value\nAAPL,15000\n"
    var data = Data(bom)
    data.append(csvString.data(using: .utf8)!)

    let result = CSVParsingService.parseAssetCSV(data: data, importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows.count == 1)
  }

  @Test("Thousand separator stripping")
  func testThousandSeparatorStripping() {
    let csv = """
      Asset Name,Market Value
      AAPL,"15,000.50"
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows[0].marketValue == Decimal(string: "15000.50"))
  }

  @Test("Currency symbol stripping")
  func testCurrencySymbolStripping() {
    let csv = """
      Asset Name,Market Value
      AAPL,$15000
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows[0].marketValue == Decimal(15000))
  }

  @Test("Whitespace trimming in values")
  func testWhitespaceTrimming() {
    let csv = """
      Asset Name,Market Value
       AAPL , 15000
      """
    let result = CSVParsingService.parseAssetCSV(data: csvData(csv), importPlatform: nil)

    #expect(result.isValid)
    #expect(result.rows[0].assetName == "AAPL")
    #expect(result.rows[0].marketValue == Decimal(15000))
  }

  // MARK: - Cash Flow CSV: Valid Parsing

  @Test("Valid cash flow CSV parses correctly")
  func testValidCashFlowCSV() {
    let csv = """
      Description,Amount
      Salary deposit,50000
      Emergency fund transfer,-10000
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.isValid)
    #expect(result.rows.count == 2)
    #expect(result.rows[0].description == "Salary deposit")
    #expect(result.rows[0].amount == Decimal(50000))
    #expect(result.rows[1].amount == Decimal(-10000))
  }

  // MARK: - Cash Flow CSV: Missing Columns

  @Test("Missing Description column returns error")
  func testMissingDescriptionColumn() {
    let csv = """
      Amount
      50000
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Description"))
  }

  @Test("Missing Amount column returns error")
  func testMissingAmountColumn() {
    let csv = """
      Description
      Salary deposit
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Amount"))
  }

  @Test("Missing both Description and Amount columns reports 2 errors")
  func testMissingBothCashFlowColumns() {
    let csv = """
      Extra
      ignored
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors.count == 2)
    #expect(result.errors.contains(where: { $0.message.contains("Description") }))
    #expect(result.errors.contains(where: { $0.message.contains("Amount") }))
  }

  // MARK: - Cash Flow CSV: Row Validation

  @Test("Empty description returns error")
  func testEmptyDescription() {
    let csv = """
      Description,Amount
      ,50000
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("empty"))
  }

  @Test("Unparseable amount returns error")
  func testUnparseableAmount() {
    let csv = """
      Description,Amount
      Deposit,abc
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors[0].message.contains("Cannot parse"))
  }

  @Test("Zero amount generates warning")
  func testZeroAmountWarning() {
    let csv = """
      Description,Amount
      No-op,0
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.isValid)
    #expect(result.warnings.contains(where: { $0.message.contains("zero") }))
  }

  // MARK: - Cash Flow CSV: Duplicate Detection

  @Test("Duplicate cash flow descriptions returns error")
  func testDuplicateCashFlowDescriptions() {
    let csv = """
      Description,Amount
      Salary deposit,50000
      Salary deposit,30000
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors.contains(where: { $0.message.contains("Duplicate") }))
  }

  @Test("Case-insensitive cash flow duplicate detection")
  func testCaseInsensitiveCashFlowDuplicates() {
    let csv = """
      Description,Amount
      Salary Deposit,50000
      salary deposit,30000
      """
    let result = CSVParsingService.parseCashFlowCSV(data: csvData(csv))

    #expect(result.hasErrors)
    #expect(result.errors.contains(where: { $0.message.contains("Duplicate") }))
  }
}

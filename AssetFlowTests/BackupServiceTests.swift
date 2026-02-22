//
//  BackupServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("BackupService Tests")
@MainActor
struct BackupServiceTests {

  // MARK: - Test Helpers

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
    let settingsService: SettingsService
  }

  private func createTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let settingsService = SettingsService.createForTesting()
    return TestContext(
      container: container, context: context,
      settingsService: settingsService)
  }

  private func tempZipURL() -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: "test-backup-\(UUID().uuidString).zip")
  }

  private func populateTestData(
    context: ModelContext, settingsService: SettingsService
  ) {
    let equities = Category(
      name: "Equities", targetAllocationPercentage: 60)
    context.insert(equities)

    let bonds = Category(name: "Bonds")
    context.insert(bonds)

    let aapl = Asset(name: "AAPL", platform: "Interactive Brokers")
    aapl.category = equities
    context.insert(aapl)

    let vti = Asset(name: "VTI", platform: "Schwab")
    vti.category = equities
    context.insert(vti)

    let btc = Asset(name: "Bitcoin", platform: "Coinbase")
    context.insert(btc)

    let date1 = Calendar.current.date(
      from: DateComponents(year: 2025, month: 6, day: 15))!
    let snapshot1 = Snapshot(date: date1)
    context.insert(snapshot1)

    let sav1 = SnapshotAssetValue(marketValue: Decimal(string: "15000.50")!)
    sav1.snapshot = snapshot1
    sav1.asset = aapl
    context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: Decimal(string: "28000.75")!)
    sav2.snapshot = snapshot1
    sav2.asset = vti
    context.insert(sav2)

    let cf1 = CashFlowOperation(
      cashFlowDescription: "Salary deposit", amount: 50000)
    cf1.snapshot = snapshot1
    context.insert(cf1)

    let cf2 = CashFlowOperation(
      cashFlowDescription: "Emergency fund transfer", amount: -10000)
    cf2.snapshot = snapshot1
    context.insert(cf2)

    settingsService.mainCurrency = "TWD"
    settingsService.dateFormat = .long
    settingsService.defaultPlatform = "Schwab"
  }

  // MARK: - Export Tests

  @Test("Export creates valid ZIP file")
  func exportCreatesValidZIP() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    #expect(FileManager.default.fileExists(atPath: zipURL.path))
  }

  @Test("Export ZIP contains all required files")
  func exportContainsAllFiles() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Extract and check files
    let extractDir = FileManager.default.temporaryDirectory
      .appending(path: "extract-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: extractDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", zipURL.path, extractDir.path]
    try process.run()
    process.waitUntilExit()

    let requiredFiles =
      [BackupCSV.manifestFileName] + BackupCSV.allCSVFileNames
      + BackupCSV.optionalCSVFileNames
    for fileName in requiredFiles {
      let exists = FileManager.default.fileExists(
        atPath: extractDir.appending(path: fileName).path)
      #expect(exists, "Missing file: \(fileName)")
    }
  }

  @Test("Export manifest has correct formatVersion, appVersion, ISO 8601 timestamp")
  func exportManifestCorrect() throws {
    let tc = createTestContext()
    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let manifest = try BackupService.validateBackup(at: zipURL)
    #expect(manifest.formatVersion == 3)
    #expect(manifest.appVersion == Constants.AppInfo.version)
    // Verify ISO 8601 timestamp is parseable
    let formatter = ISO8601DateFormatter()
    #expect(formatter.date(from: manifest.exportTimestamp) != nil)
  }

  @Test("Export categories CSV has correct headers and data")
  func exportCategoriesCSV() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Categories.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    #expect(lines[0] == "id,name,targetAllocationPercentage,displayOrder")
    #expect(lines.count == 3)  // header + 2 categories
  }

  @Test("Export assets CSV has correct headers and data")
  func exportAssetsCSV() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Assets.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    #expect(lines[0] == "id,name,platform,categoryID,currency")
    #expect(lines.count == 4)  // header + 3 assets
  }

  @Test("Export settings CSV includes all 3 settings")
  func exportSettingsCSV() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Settings.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    #expect(lines[0] == "key,value")
    #expect(lines.count == 4)  // header + 3 settings
    #expect(lines.contains { $0.contains("displayCurrency") && $0.contains("TWD") })
    #expect(lines.contains { $0.contains("dateFormat") && $0.contains("long") })
    #expect(lines.contains { $0.contains("defaultPlatform") && $0.contains("Schwab") })
  }

  @Test("Empty database exports valid archive with header-only CSVs")
  func emptyDatabaseExport() throws {
    let tc = createTestContext()
    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Should be valid
    let manifest = try BackupService.validateBackup(at: zipURL)
    #expect(manifest.formatVersion == 3)

    // Categories CSV should have only header
    let catContent = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Categories.fileName)
    let catLines = catContent.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    #expect(catLines.count == 1)
  }

  @Test("Export handles optional fields (nil to empty string)")
  func exportHandlesOptionalFields() throws {
    let tc = createTestContext()

    // Category without target
    let cat = Category(name: "Other")
    tc.context.insert(cat)

    // Asset without category
    let asset = Asset(name: "Gold", platform: "")
    tc.context.insert(asset)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let catContent = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Categories.fileName)
    let catLines = catContent.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    // Should have empty field for target (format: id,name,,displayOrder)
    let dataLine = catLines[1]
    #expect(dataLine.contains(",,"))

    let assetContent = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Assets.fileName)
    let assetLines = assetContent.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    // Should have empty categoryID
    let assetDataLine = assetLines[1]
    #expect(assetDataLine.hasSuffix(","))
  }

  @Test("Export serializes Decimal at full precision")
  func exportDecimalPrecision() throws {
    let tc = createTestContext()

    let snapshot = Snapshot(
      date: Calendar.current.date(
        from: DateComponents(year: 2025, month: 1, day: 1))!)
    tc.context.insert(snapshot)

    let asset = Asset(name: "Test", platform: "")
    tc.context.insert(asset)

    let preciseValue = Decimal(string: "12345.6789012345")!
    let sav = SnapshotAssetValue(marketValue: preciseValue)
    sav.snapshot = snapshot
    sav.asset = asset
    tc.context.insert(sav)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.SnapshotAssetValues.fileName)
    #expect(content.contains("12345.6789012345"))
  }

  // MARK: - Validation Tests

  @Test("Validate accepts valid archive")
  func validateAcceptsValid() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let manifest = try BackupService.validateBackup(at: zipURL)
    #expect(manifest.formatVersion == 3)
  }

  @Test("Validate rejects non-ZIP file")
  func validateRejectsNonZIP() throws {
    let url = tempZipURL()
    defer { try? FileManager.default.removeItem(at: url) }

    try "not a zip file".write(
      to: url, atomically: true, encoding: .utf8)

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: url)
    }
  }

  @Test("Validate rejects archive missing required CSV")
  func validateRejectsMissingCSV() throws {
    let tc = createTestContext()

    // Create a backup, then remove one CSV and re-zip
    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    try tamperAndRezip(zipURL: zipURL) { dir in
      try FileManager.default.removeItem(
        at: dir.appending(path: BackupCSV.Categories.fileName))
    }

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: zipURL)
    }
  }

  @Test("Validate rejects wrong CSV headers")
  func validateRejectsWrongHeaders() throws {
    let tc = createTestContext()

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    try tamperAndRezip(zipURL: zipURL) { dir in
      let catFile = dir.appending(path: BackupCSV.Categories.fileName)
      try "wrong,headers,here\n".write(
        to: catFile, atomically: true, encoding: .utf8)
    }

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: zipURL)
    }
  }

  @Test("Validate rejects orphan categoryID")
  func validateRejectsOrphanCategoryID() throws {
    let tc = createTestContext()

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let fakeID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let assetFile = dir.appending(path: BackupCSV.Assets.fileName)
      try "id,name,platform,categoryID\n\(UUID().uuidString),FakeAsset,Platform,\(fakeID)\n"
        .write(to: assetFile, atomically: true, encoding: .utf8)
    }

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: zipURL)
    }
  }

  @Test("Validate accepts empty categoryID (uncategorized asset)")
  func validateAcceptsEmptyCategoryID() throws {
    let tc = createTestContext()

    // Create asset without category
    let asset = Asset(name: "Uncategorized", platform: "")
    tc.context.insert(asset)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Should not throw
    let manifest = try BackupService.validateBackup(at: zipURL)
    #expect(manifest.formatVersion == 3)
  }

  @Test("Validate rejects orphan snapshotID in snapshot_asset_values")
  func validateRejectsOrphanSnapshotID() throws {
    let tc = createTestContext()

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    // Create an asset so there's a valid assetID
    let asset = Asset(name: "Test", platform: "")
    tc.context.insert(asset)

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let fakeSnapID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let savFile = dir.appending(
        path: BackupCSV.SnapshotAssetValues.fileName)
      try "snapshotID,assetID,marketValue\n\(fakeSnapID),\(asset.id.uuidString),1000\n"
        .write(to: savFile, atomically: true, encoding: .utf8)
    }

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: zipURL)
    }
  }

  @Test("Validate rejects orphan assetID in snapshot_asset_values")
  func validateRejectsOrphanAssetID() throws {
    let tc = createTestContext()

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    // Create a snapshot so there's a valid snapshotID
    let snapshot = Snapshot(
      date: Calendar.current.date(
        from: DateComponents(year: 2025, month: 1, day: 1))!)
    tc.context.insert(snapshot)

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let fakeAssetID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let savFile = dir.appending(
        path: BackupCSV.SnapshotAssetValues.fileName)
      try "snapshotID,assetID,marketValue\n\(snapshot.id.uuidString),\(fakeAssetID),1000\n"
        .write(to: savFile, atomically: true, encoding: .utf8)
    }

    #expect(throws: BackupError.self) {
      try BackupService.validateBackup(at: zipURL)
    }
  }

  // MARK: - Round-Trip Tests

  @Test("Round-trip preserves all categories")
  func roundTripCategories() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Restore into fresh context
    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 2)
    #expect(categories.contains { $0.name == "Equities" && $0.targetAllocationPercentage == 60 })
    #expect(categories.contains { $0.name == "Bonds" && $0.targetAllocationPercentage == nil })
  }

  @Test("Round-trip preserves all assets with category relationships")
  func roundTripAssets() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let assets = try tc2.context.fetch(FetchDescriptor<Asset>())
    #expect(assets.count == 3)

    let aapl = assets.first { $0.name == "AAPL" }
    #expect(aapl?.platform == "Interactive Brokers")
    #expect(aapl?.category?.name == "Equities")

    let btc = assets.first { $0.name == "Bitcoin" }
    #expect(btc?.category == nil)
  }

  @Test("Round-trip preserves all snapshots")
  func roundTripSnapshots() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let snapshots = try tc2.context.fetch(FetchDescriptor<Snapshot>())
    #expect(snapshots.count == 1)
  }

  @Test("Round-trip preserves all snapshot asset values with relationships")
  func roundTripSnapshotAssetValues() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let savs = try tc2.context.fetch(
      FetchDescriptor<SnapshotAssetValue>())
    #expect(savs.count == 2)

    let aaplSav = savs.first { $0.asset?.name == "AAPL" }
    #expect(aaplSav?.marketValue == Decimal(string: "15000.50"))
    #expect(aaplSav?.snapshot != nil)
  }

  @Test("Round-trip preserves all cash flow operations")
  func roundTripCashFlowOperations() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let ops = try tc2.context.fetch(
      FetchDescriptor<CashFlowOperation>())
    #expect(ops.count == 2)

    let salary = ops.first { $0.cashFlowDescription == "Salary deposit" }
    #expect(salary?.amount == 50000)
    #expect(salary?.snapshot != nil)
  }

  @Test("Round-trip preserves settings")
  func roundTripSettings() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    #expect(tc2.settingsService.mainCurrency == "TWD")
    #expect(tc2.settingsService.dateFormat == .long)
    #expect(tc2.settingsService.defaultPlatform == "Schwab")
  }

  @Test("Round-trip preserves Decimal precision")
  func roundTripDecimalPrecision() throws {
    let tc = createTestContext()

    let snapshot = Snapshot(
      date: Calendar.current.date(
        from: DateComponents(year: 2025, month: 1, day: 1))!)
    tc.context.insert(snapshot)

    let asset = Asset(name: "Test", platform: "")
    tc.context.insert(asset)

    let preciseValue = Decimal(string: "12345.6789012345")!
    let sav = SnapshotAssetValue(marketValue: preciseValue)
    sav.snapshot = snapshot
    sav.asset = asset
    tc.context.insert(sav)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let savs = try tc2.context.fetch(
      FetchDescriptor<SnapshotAssetValue>())
    #expect(savs.count == 1)
    #expect(savs[0].marketValue == preciseValue)
  }

  @Test("Restore replaces ALL existing data")
  func restoreReplacesExistingData() throws {
    let tc = createTestContext()
    populateTestData(
      context: tc.context, settingsService: tc.settingsService)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Create a different context with different data
    let tc2 = createTestContext()
    let otherCat = Category(name: "Other Category")
    tc2.context.insert(otherCat)
    let otherAsset = Asset(name: "Other Asset", platform: "Other")
    tc2.context.insert(otherAsset)

    // Restore — should replace the "Other" data with the backup data
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 2)
    #expect(!categories.contains { $0.name == "Other Category" })

    let assets = try tc2.context.fetch(FetchDescriptor<Asset>())
    #expect(assets.count == 3)
    #expect(!assets.contains { $0.name == "Other Asset" })
  }

  @Test("Restore empty backup clears all data")
  func restoreEmptyBackupClearsData() throws {
    let tc = createTestContext()

    // Export empty database
    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Create context with data
    let tc2 = createTestContext()
    populateTestData(
      context: tc2.context, settingsService: tc2.settingsService)

    // Restore empty backup
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.isEmpty)

    let assets = try tc2.context.fetch(FetchDescriptor<Asset>())
    #expect(assets.isEmpty)

    let snapshots = try tc2.context.fetch(FetchDescriptor<Snapshot>())
    #expect(snapshots.isEmpty)
  }

  @Test("Export/round-trip handles commas, quotes, special chars in text fields")
  func roundTripSpecialCharacters() throws {
    let tc = createTestContext()

    let cat = Category(name: "Stocks, \"Growth\"")
    tc.context.insert(cat)

    let asset = Asset(
      name: "S&P 500, \"Total Return\"", platform: "Platform (A)")
    asset.category = cat
    tc.context.insert(asset)

    let snapshot = Snapshot(
      date: Calendar.current.date(
        from: DateComponents(year: 2025, month: 1, day: 1))!)
    tc.context.insert(snapshot)

    let cf = CashFlowOperation(
      cashFlowDescription: "Transfer, \"special\"", amount: 1000)
    cf.snapshot = snapshot
    tc.context.insert(cf)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.first?.name == "Stocks, \"Growth\"")

    let assets = try tc2.context.fetch(FetchDescriptor<Asset>())
    #expect(assets.first?.name == "S&P 500, \"Total Return\"")
    #expect(assets.first?.platform == "Platform (A)")

    let ops = try tc2.context.fetch(
      FetchDescriptor<CashFlowOperation>())
    #expect(ops.first?.cashFlowDescription == "Transfer, \"special\"")
  }

  // MARK: - Nil Relationship Export Tests

  @Test("Export skips snapshot asset values with nil relationships")
  func exportSkipsSnapshotAssetValuesWithNilRelationships() throws {
    let tc = createTestContext()

    // Create a SAV with nil snapshot (orphaned)
    let sav = SnapshotAssetValue(marketValue: 1000)
    tc.context.insert(sav)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.SnapshotAssetValues.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    // Should have only the header — the nil-relationship row should be skipped
    #expect(lines.count == 1)
  }

  @Test("Export skips cash flow operations with nil snapshot")
  func exportSkipsCashFlowOperationsWithNilSnapshot() throws {
    let tc = createTestContext()

    // Create a CF with nil snapshot (orphaned)
    let cf = CashFlowOperation(
      cashFlowDescription: "Orphan", amount: 500)
    tc.context.insert(cf)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.CashFlowOperations.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    // Should have only the header — the nil-snapshot row should be skipped
    #expect(lines.count == 1)
  }

  // MARK: - Unresolvable ID Tests

  @Test("Restore rejects unresolvable snapshotID in snapshot_asset_values")
  func restoreRejectsUnresolvableSnapshotIDInSAV() throws {
    let tc = createTestContext()

    let asset = Asset(name: "Test", platform: "")
    tc.context.insert(asset)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Tamper SAV to reference a snapshotID not in snapshots.csv
    let bogusSnapID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let savFile = dir.appending(
        path: BackupCSV.SnapshotAssetValues.fileName)
      try "snapshotID,assetID,marketValue\n\(bogusSnapID),\(asset.id.uuidString),1000\n"
        .write(to: savFile, atomically: true, encoding: .utf8)
    }

    let tc2 = createTestContext()
    #expect(throws: BackupError.self) {
      try BackupService.restoreFromBackup(
        at: zipURL, modelContext: tc2.context,
        settingsService: tc2.settingsService)
    }
  }

  @Test("Restore rejects unresolvable assetID in snapshot_asset_values")
  func restoreRejectsUnresolvableAssetIDInSAV() throws {
    let tc = createTestContext()

    let snapshot = Snapshot(
      date: Calendar.current.date(
        from: DateComponents(year: 2025, month: 1, day: 1))!)
    tc.context.insert(snapshot)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Tamper SAV to reference an assetID not in assets.csv
    let bogusAssetID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let savFile = dir.appending(
        path: BackupCSV.SnapshotAssetValues.fileName)
      try "snapshotID,assetID,marketValue\n\(snapshot.id.uuidString),\(bogusAssetID),1000\n"
        .write(to: savFile, atomically: true, encoding: .utf8)
    }

    let tc2 = createTestContext()
    #expect(throws: BackupError.self) {
      try BackupService.restoreFromBackup(
        at: zipURL, modelContext: tc2.context,
        settingsService: tc2.settingsService)
    }
  }

  @Test("Restore rejects unresolvable snapshotID in cash_flow_operations")
  func restoreRejectsUnresolvableSnapshotIDInCashFlow() throws {
    let tc = createTestContext()

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Tamper CF to reference a snapshotID not in snapshots.csv
    let bogusSnapID = UUID().uuidString
    try tamperAndRezip(zipURL: zipURL) { dir in
      let cfFile = dir.appending(
        path: BackupCSV.CashFlowOperations.fileName)
      try "id,snapshotID,description,amount\n\(UUID().uuidString),\(bogusSnapID),Test,100\n"
        .write(to: cfFile, atomically: true, encoding: .utf8)
    }

    let tc2 = createTestContext()
    #expect(throws: BackupError.self) {
      try BackupService.restoreFromBackup(
        at: zipURL, modelContext: tc2.context,
        settingsService: tc2.settingsService)
    }
  }

  // MARK: - Display Order Tests

  @Test("Backup export includes displayOrder column")
  func backupExportIncludesDisplayOrder() throws {
    let tc = createTestContext()

    let equities = Category(
      name: "Equities", targetAllocationPercentage: 60)
    equities.displayOrder = 1
    tc.context.insert(equities)

    let bonds = Category(name: "Bonds")
    bonds.displayOrder = 0
    tc.context.insert(bonds)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let content = try extractFileContent(
      zipURL: zipURL, fileName: BackupCSV.Categories.fileName)
    let lines = content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
    #expect(lines[0] == "id,name,targetAllocationPercentage,displayOrder")
    #expect(lines.count == 3)
    // Verify displayOrder is the last field in each data row
    for line in lines.dropFirst() {
      let fields = line.components(separatedBy: ",")
      let lastField = fields.last?.trimmingCharacters(in: .whitespaces) ?? ""
      #expect(Int(lastField) != nil, "Last field should be displayOrder integer, got: \(lastField)")
    }
  }

  @Test("Restore handles old backup without displayOrder column")
  func restoreHandlesOldBackupWithoutDisplayOrder() throws {
    let tc = createTestContext()

    // Create a v1 backup (3-column categories.csv)
    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    // Export a normal backup first
    let cat = Category(name: "TestCat", targetAllocationPercentage: 50)
    tc.context.insert(cat)
    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    // Tamper to create v1 format (3-column categories, formatVersion 1)
    try tamperAndRezip(zipURL: zipURL) { dir in
      // Rewrite categories.csv without displayOrder column
      let catFile = dir.appending(path: BackupCSV.Categories.fileName)
      try "id,name,targetAllocationPercentage\n\(cat.id.uuidString),TestCat,50\n"
        .write(to: catFile, atomically: true, encoding: .utf8)

      // Rewrite manifest with formatVersion 1
      let manifestURL = dir.appending(path: BackupCSV.manifestFileName)
      let manifest = BackupManifest(
        formatVersion: 1,
        exportTimestamp: ISO8601DateFormatter().string(from: Date()),
        appVersion: "1.0.0"
      )
      try JSONEncoder().encode(manifest).write(to: manifestURL)
    }

    // Restore into a fresh context
    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 1)
    #expect(categories[0].name == "TestCat")
    #expect(categories[0].displayOrder == 0)
  }

  @Test("Round-trip preserves displayOrder")
  func roundTripDisplayOrder() throws {
    let tc = createTestContext()

    let equities = Category(
      name: "Equities", targetAllocationPercentage: 60)
    equities.displayOrder = 2
    tc.context.insert(equities)

    let bonds = Category(name: "Bonds")
    bonds.displayOrder = 0
    tc.context.insert(bonds)

    let crypto = Category(name: "Crypto")
    crypto.displayOrder = 1
    tc.context.insert(crypto)

    let zipURL = tempZipURL()
    defer { try? FileManager.default.removeItem(at: zipURL) }

    try BackupService.exportBackup(
      to: zipURL, modelContext: tc.context,
      settingsService: tc.settingsService)

    let tc2 = createTestContext()
    try BackupService.restoreFromBackup(
      at: zipURL, modelContext: tc2.context,
      settingsService: tc2.settingsService)

    let categories = try tc2.context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 3)
    let restoredBonds = categories.first { $0.name == "Bonds" }
    let restoredCrypto = categories.first { $0.name == "Crypto" }
    let restoredEquities = categories.first { $0.name == "Equities" }
    #expect(restoredBonds?.displayOrder == 0)
    #expect(restoredCrypto?.displayOrder == 1)
    #expect(restoredEquities?.displayOrder == 2)
  }

  // MARK: - Tamper and Rezip Helper

  /// Extracts a ZIP archive, applies a tampering closure, and re-zips in place.
  private func tamperAndRezip(
    zipURL: URL,
    tamper: (URL) throws -> Void
  ) throws {
    let extractDir = FileManager.default.temporaryDirectory
      .appending(path: "tamper-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: extractDir) }

    let dittoExtract = Process()
    dittoExtract.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    dittoExtract.arguments = ["-x", "-k", zipURL.path, extractDir.path]
    try dittoExtract.run()
    dittoExtract.waitUntilExit()

    try tamper(extractDir)

    try FileManager.default.removeItem(at: zipURL)
    let dittoCreate = Process()
    dittoCreate.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    dittoCreate.arguments = [
      "-c", "-k", "--sequesterRsrc", extractDir.path, zipURL.path,
    ]
    try dittoCreate.run()
    dittoCreate.waitUntilExit()
  }

  // MARK: - Helper to extract file content from ZIP

  private func extractFileContent(
    zipURL: URL, fileName: String
  ) throws -> String {
    let extractDir = FileManager.default.temporaryDirectory
      .appending(path: "extract-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: extractDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", zipURL.path, extractDir.path]
    try process.run()
    process.waitUntilExit()

    return try String(
      contentsOf: extractDir.appending(path: fileName),
      encoding: .utf8)
  }
}

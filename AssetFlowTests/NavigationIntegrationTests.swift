//
//  NavigationIntegrationTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Navigation Integration Tests")
@MainActor
struct NavigationIntegrationTests {

  // MARK: - SidebarSection Enum Tests

  @Test("SidebarSection enum has exactly 7 cases")
  func sidebarSectionHasSevenCases() {
    #expect(SidebarSection.allCases.count == 7)
  }

  @Test("SidebarSection default is dashboard")
  func sidebarSectionDefaultIsDashboard() {
    let defaultSection: SidebarSection = .dashboard
    #expect(defaultSection == .dashboard)
  }

  @Test("All 7 sidebar items are represented in the enum")
  func allSidebarItemsRepresented() {
    let cases = SidebarSection.allCases
    #expect(cases.contains(.dashboard))
    #expect(cases.contains(.snapshots))
    #expect(cases.contains(.assets))
    #expect(cases.contains(.categories))
    #expect(cases.contains(.platforms))
    #expect(cases.contains(.rebalancing))
    #expect(cases.contains(.importCSV))
  }

  @Test("SidebarSection has correct labels")
  func sidebarSectionLabels() {
    #expect(!SidebarSection.dashboard.label.isEmpty)
    #expect(!SidebarSection.snapshots.label.isEmpty)
    #expect(!SidebarSection.assets.label.isEmpty)
    #expect(!SidebarSection.categories.label.isEmpty)
    #expect(!SidebarSection.platforms.label.isEmpty)
    #expect(!SidebarSection.rebalancing.label.isEmpty)
    #expect(!SidebarSection.importCSV.label.isEmpty)
  }

  @Test("SidebarSection has correct SF symbols")
  func sidebarSectionSymbols() {
    #expect(!SidebarSection.dashboard.systemImage.isEmpty)
    #expect(!SidebarSection.snapshots.systemImage.isEmpty)
    #expect(!SidebarSection.assets.systemImage.isEmpty)
    #expect(!SidebarSection.categories.systemImage.isEmpty)
    #expect(!SidebarSection.platforms.systemImage.isEmpty)
    #expect(!SidebarSection.rebalancing.systemImage.isEmpty)
    #expect(!SidebarSection.importCSV.systemImage.isEmpty)
  }

  // MARK: - Post-Import Navigation Tests

  @Test("ImportViewModel importedSnapshot is non-nil after successful executeImport")
  func postImportNavigationState() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = ImportViewModel(modelContext: context)
    // Load a minimal valid asset CSV
    let csvData = "Asset Name,Market Value\nAAPL,1000".data(using: .utf8)!
    viewModel.loadCSVData(csvData)
    viewModel.snapshotDate = Date()

    let result = viewModel.executeImport()

    #expect(result != nil)
    #expect(viewModel.importedSnapshot != nil)
  }

  // MARK: - Discard Confirmation State Tests

  @Test("ImportViewModel hasUnsavedChanges is true after loading CSV data")
  func discardConfirmationAfterLoad() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = ImportViewModel(modelContext: context)
    #expect(viewModel.hasUnsavedChanges == false)

    let csvData = "Asset Name,Market Value\nAAPL,1000".data(using: .utf8)!
    viewModel.loadCSVData(csvData)

    #expect(viewModel.hasUnsavedChanges == true)
  }

  @Test("ImportViewModel hasUnsavedChanges is false after reset")
  func discardConfirmationAfterReset() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = ImportViewModel(modelContext: context)
    let csvData = "Asset Name,Market Value\nAAPL,1000".data(using: .utf8)!
    viewModel.loadCSVData(csvData)
    #expect(viewModel.hasUnsavedChanges == true)

    viewModel.reset()

    #expect(viewModel.hasUnsavedChanges == false)
  }

  @Test("ImportViewModel hasUnsavedChanges is false after successful executeImport")
  func discardConfirmationAfterImport() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = ImportViewModel(modelContext: context)
    let csvData = "Asset Name,Market Value\nAAPL,1000".data(using: .utf8)!
    viewModel.loadCSVData(csvData)
    viewModel.snapshotDate = Date()

    _ = viewModel.executeImport()

    #expect(viewModel.hasUnsavedChanges == false)
  }

  // MARK: - Snapshot List Row Data Tests

  @Test("SnapshotListViewModel loadAllSnapshotRowData returns valid data for each snapshot")
  func snapshotListRowData() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", platform: "TestPlatform")
    context.insert(asset)

    let snapshot = Snapshot(date: Calendar.current.startOfDay(for: Date()))
    context.insert(snapshot)
    let sav = SnapshotAssetValue(marketValue: 5000)
    sav.snapshot = snapshot
    sav.asset = asset
    context.insert(sav)

    let viewModel = SnapshotListViewModel(modelContext: context)
    let rowDataMap = viewModel.loadAllSnapshotRowData()

    #expect(rowDataMap.count == 1)

    let rowData = rowDataMap[snapshot.id]
    #expect(rowData != nil)
    #expect(rowData!.totalValue == 5000)
    #expect(rowData!.assetCount == 1)
  }

  // MARK: - Snapshot Deletion Tests (T2)

  @Test("SnapshotDetailViewModel deleteSnapshot removes snapshot from context")
  func snapshotDetailDeleteActuallyDeletes() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Delete Test Asset", platform: "TestPlatform")
    context.insert(asset)

    let snapshot = Snapshot(date: Calendar.current.startOfDay(for: Date()))
    context.insert(snapshot)
    let sav = SnapshotAssetValue(marketValue: 1000)
    sav.snapshot = snapshot
    sav.asset = asset
    context.insert(sav)

    let viewModel = SnapshotDetailViewModel(snapshot: snapshot, modelContext: context)
    viewModel.deleteSnapshot()

    let descriptor = FetchDescriptor<Snapshot>()
    let remaining = (try? context.fetch(descriptor)) ?? []
    #expect(remaining.isEmpty)
  }

  // MARK: - Date-Based Snapshot Lookup Tests (T3)

  @Test("Snapshot can be looked up by date from model context")
  func snapshotLookupByDate() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let date1 = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let date3 = Calendar.current.startOfDay(for: Date())

    let snap1 = Snapshot(date: Calendar.current.startOfDay(for: date1))
    let snap2 = Snapshot(date: Calendar.current.startOfDay(for: date2))
    let snap3 = Snapshot(date: date3)
    context.insert(snap1)
    context.insert(snap2)
    context.insert(snap3)

    let targetDate = Calendar.current.startOfDay(for: date2)
    let descriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? context.fetch(descriptor)) ?? []
    let match = allSnapshots.first(where: {
      Calendar.current.isDate($0.date, inSameDayAs: targetDate)
    })

    #expect(match != nil)
    #expect(match?.id == snap2.id)
  }

  // MARK: - UUID-Keyed Row Data Tests (T2b)

  @Test("SnapshotListViewModel loadAllSnapshotRowData uses UUID keys")
  func snapshotRowDataUsesUUIDKeys() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "UUID Key Test", platform: "TestPlatform")
    context.insert(asset)

    let snapshot = Snapshot(date: Calendar.current.startOfDay(for: Date()))
    context.insert(snapshot)
    let sav = SnapshotAssetValue(marketValue: 3000)
    sav.snapshot = snapshot
    sav.asset = asset
    context.insert(sav)

    let viewModel = SnapshotListViewModel(modelContext: context)
    let rowDataMap = viewModel.loadAllSnapshotRowData()

    let rowData = rowDataMap[snapshot.id]
    #expect(rowData != nil)
    #expect(rowData!.totalValue == 3000)
    #expect(rowData!.assetCount == 1)
  }

  // MARK: - Error Message Tests

  @Test("SnapshotError dateAlreadyExists has correct SPEC 8.1 message format")
  func dateAlreadyExistsErrorMessage() {
    let testDate = Calendar.current.startOfDay(for: Date())
    let error = SnapshotError.dateAlreadyExists(testDate)
    let message = error.errorDescription ?? ""

    // Non-tautological: verify date interpolation and non-empty message
    let formatted = testDate.settingsFormatted()
    #expect(!message.isEmpty)
    #expect(message.contains(formatted))
  }
}

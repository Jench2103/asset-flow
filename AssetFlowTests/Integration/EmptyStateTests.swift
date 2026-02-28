//
//  EmptyStateTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Empty State Tests")
@MainActor
struct EmptyStateTests {

  // MARK: - Test Helpers

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
  }

  private func createTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    return TestContext(container: container, context: context)
  }

  // MARK: - DashboardViewModel

  @Test("DashboardViewModel isEmpty is true when no snapshots exist")
  func dashboardViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()
    #expect(viewModel.isEmpty == true)
  }

  @Test("DashboardViewModel isEmpty is false when snapshots exist")
  func dashboardViewModelNonEmptyState() {
    let tc = createTestContext()
    let snapshot = Snapshot(date: Date())
    tc.context.insert(snapshot)
    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()
    #expect(viewModel.isEmpty == false)
  }

  // MARK: - RebalancingViewModel

  @Test("RebalancingViewModel isEmpty is true when no categories have targets")
  func rebalancingViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = RebalancingViewModel(modelContext: tc.context)
    viewModel.loadRebalancing()
    #expect(viewModel.isEmpty == true)
  }

  // MARK: - CategoryListViewModel

  @Test("CategoryListViewModel categoryRows is empty when no categories exist")
  func categoryListViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = CategoryListViewModel(modelContext: tc.context)
    viewModel.loadCategories()
    #expect(viewModel.categoryRows.isEmpty == true)
  }

  // MARK: - AssetListViewModel

  @Test("AssetListViewModel groups is empty when no assets exist")
  func assetListViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = AssetListViewModel(modelContext: tc.context)
    viewModel.loadAssets()
    #expect(viewModel.groups.isEmpty == true)
  }

  // MARK: - SnapshotListViewModel

  @Test("SnapshotListViewModel returns empty row data when no snapshots exist")
  func snapshotListViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = SnapshotListViewModel(modelContext: tc.context)
    let rowDataMap = viewModel.loadAllSnapshotRowData()
    #expect(rowDataMap.isEmpty == true)
  }

  // MARK: - PlatformListViewModel

  @Test("PlatformListViewModel platformRows is empty when no assets exist")
  func platformListViewModelEmptyState() {
    let tc = createTestContext()
    let viewModel = PlatformListViewModel(modelContext: tc.context)
    viewModel.loadPlatforms()
    #expect(viewModel.platformRows.isEmpty == true)
  }
}

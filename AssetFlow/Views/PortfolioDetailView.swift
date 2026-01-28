//
//  PortfolioDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

/// Portfolio Detail View - Displays assets in a portfolio
///
/// Primary platform: macOS
/// This view shows the list of assets belonging to a portfolio, along with
/// their quantities and values. It also displays the total value of the portfolio.
struct PortfolioDetailView: View {
  @State var viewModel: PortfolioDetailViewModel
  @State var assetManagementViewModel: AssetManagementViewModel
  @Environment(\.modelContext) private var modelContext
  @State private var showingAddAsset = false
  @State private var editingAsset: Asset?
  @State private var priceHistoryAsset: Asset?

  var body: some View {
    Group {
      if viewModel.assets.isEmpty {
        emptyStateView
      } else {
        assetListContent
      }
    }
    .navigationTitle(viewModel.portfolio.name)
    #if os(macOS)
      .navigationSubtitle(viewModel.portfolio.portfolioDescription ?? "")
    #endif
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          Task {
            await viewModel.refresh()
          }
        } label: {
          Label("Refresh Rates", systemImage: "arrow.clockwise")
        }
        .disabled(viewModel.isLoadingRates)
      }

      ToolbarItem(placement: .primaryAction) {
        Button("Add Asset") {
          showingAddAsset = true
        }
        .accessibilityIdentifier("Add Asset")
      }
    }
    .sheet(
      isPresented: $showingAddAsset,
      onDismiss: {
        viewModel.calculateTotalValue()
      },
      content: {
        NavigationStack {
          AssetFormView(
            viewModel: AssetFormViewModel(
              modelContext: modelContext, portfolio: viewModel.portfolio)
          )
        }
      }
    )
    .sheet(
      item: $editingAsset,
      onDismiss: {
        viewModel.calculateTotalValue()
      },
      content: { asset in
        NavigationStack {
          AssetFormView(
            viewModel: AssetFormViewModel(
              modelContext: modelContext, portfolio: viewModel.portfolio, asset: asset)
          )
        }
      }
    )
    .confirmationDialog(
      "Delete Asset",
      isPresented: $assetManagementViewModel.showingDeleteConfirmation,
      presenting: assetManagementViewModel.assetToDelete,
      actions: { _ in
        Button("Delete", role: .destructive) {
          assetManagementViewModel.confirmDelete()
          // Give SwiftData a moment to update the @Query results
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.calculateTotalValue()
          }
        }
        Button("Cancel", role: .cancel) {
          assetManagementViewModel.cancelDelete()
        }
      },
      message: { asset in
        Text("Are you sure you want to delete '\(asset.name)'? This action cannot be undone.")
      }
    )
    .alert(
      "Failed to Delete Asset",
      isPresented: $assetManagementViewModel.showingDeletionError,
      presenting: assetManagementViewModel.deletionError,
      actions: { _ in
        Button("OK") {
          assetManagementViewModel.deletionError = nil
          assetManagementViewModel.showingDeletionError = false
        }
      },
      message: { error in
        Text(error.errorDescription ?? "An unknown error occurred.")
      }
    )
    .sheet(
      item: $priceHistoryAsset,
      onDismiss: {
        viewModel.calculateTotalValue()
      },
      content: { asset in
        NavigationStack {
          PriceHistoryView(
            asset: asset,
            managementViewModel: PriceHistoryManagementViewModel(
              asset: asset, modelContext: modelContext)
          )
        }
      }
    )
  }

  // MARK: - Asset List Content

  private var assetListContent: some View {
    VStack(spacing: 0) {
      // Portfolio Summary Header
      portfolioSummaryHeader

      // Assets List
      List {
        ForEach(viewModel.assets) { asset in
          NavigationLink(value: asset) {
            AssetRowView(asset: asset)
          }
          .accessibilityIdentifier("Asset-\(asset.name)")
          .contextMenu {
            Button {
              editingAsset = asset
            } label: {
              Label("Edit", systemImage: "pencil")
            }

            Button {
              priceHistoryAsset = asset
            } label: {
              Label("View Price History", systemImage: "chart.line.uptrend.xyaxis")
            }

            Divider()

            Button(role: .destructive) {
              assetManagementViewModel.initiateDelete(asset: asset)
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
      .accessibilityIdentifier("Asset List")
      .navigationDestination(for: Asset.self) { asset in
        AssetDetailView(asset: asset)
      }
    }
  }

  // MARK: - Portfolio Summary Header

  private var portfolioSummaryHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "chart.pie.fill")
          .font(.title2)
          .foregroundStyle(.blue)

        Text("Total Value")
          .font(.headline)
          .foregroundStyle(.secondary)

        Spacer()
      }

      HStack {
        if viewModel.isLoadingRates {
          ProgressView()
            .scaleEffect(0.8)
          Text("Loading exchange rates...")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.secondary)
        } else {
          Text(viewModel.totalValueInMainCurrency.formatted(currency: viewModel.mainCurrency))
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(.primary)
        }
        Spacer()
      }

      HStack(spacing: 16) {
        Label("\(viewModel.assets.count) assets", systemImage: "list.bullet")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Spacer()
      }

      // Error message if exchange rates failed to load
      if let errorMessage = viewModel.exchangeRateError {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text(errorMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
    .padding(.horizontal)
    .padding(.top, 8)
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "chart.bar.doc.horizontal")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("Empty State Icon")

      VStack(spacing: 8) {
        Text("No assets yet")
          .font(.title2)
          .fontWeight(.semibold)
          .accessibilityIdentifier("No assets yet")

        Text("Add your first asset to this portfolio")
          .font(.body)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("Add your first asset to this portfolio")
      }

      Button {
        showingAddAsset = true
      } label: {
        Label("Add Asset", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("Add Asset Empty State")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - Asset Row View

/// Individual row for displaying an asset in the list
private struct AssetRowView: View {
  let asset: Asset

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(asset.name)
          .font(.headline)
          .accessibilityIdentifier(asset.name)

        Text(asset.assetType.localizedName)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(asset.assetType.rawValue)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text(asset.currentValue.formatted(currency: asset.currency))
          .font(.body)
          .fontWeight(.medium)

        // Only show quantity for non-cash assets
        if asset.assetType != .cash {
          HStack(spacing: 4) {
            Text("Quantity:")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(asset.quantity.formatted())
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        // Latest price date
        if let priceDate = asset.currentPriceDate {
          Text("Updated: \(priceDate.formattedDate)")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("No price recorded")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Previews

#Preview("With Assets") {
  let container = PreviewContainer.container
  let context = container.mainContext

  // Create portfolio with assets
  let portfolio = Portfolio(name: "Tech Portfolio", portfolioDescription: "High-growth tech stocks")
  context.insert(portfolio)

  // Asset 1: Apple
  let apple = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: portfolio)
  context.insert(apple)
  context.insert(PriceHistory(date: Date(), price: 150.0, asset: apple))
  context.insert(
    Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 100.0,
      totalAmount: 1000.0, asset: apple))

  // Asset 2: Microsoft
  let microsoft = Asset(
    name: "Microsoft Corp.", assetType: .stock, currency: "USD", portfolio: portfolio)
  context.insert(microsoft)
  context.insert(PriceHistory(date: Date(), price: 350.0, asset: microsoft))
  context.insert(
    Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: 5, pricePerUnit: 300.0,
      totalAmount: 1500.0, asset: microsoft))

  // Asset 3: Cash
  let cash = Asset(name: "USD Cash", assetType: .cash, currency: "USD", portfolio: portfolio)
  context.insert(cash)
  context.insert(PriceHistory(date: Date(), price: 1.0, asset: cash))
  context.insert(
    Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: 5000, pricePerUnit: 1.0,
      totalAmount: 5000.0, asset: cash))

  let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)
  let assetManagementViewModel = AssetManagementViewModel(modelContext: context)

  return NavigationStack {
    PortfolioDetailView(viewModel: viewModel, assetManagementViewModel: assetManagementViewModel)
  }
  .modelContainer(container)
}

#Preview("Empty Portfolio") {
  let container = PreviewContainer.container
  let context = container.mainContext

  let portfolio = Portfolio(name: "Empty Portfolio", portfolioDescription: "No assets yet")
  context.insert(portfolio)

  let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)
  let assetManagementViewModel = AssetManagementViewModel(modelContext: context)

  return NavigationStack {
    PortfolioDetailView(viewModel: viewModel, assetManagementViewModel: assetManagementViewModel)
  }
  .modelContainer(container)
}

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
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    Group {
      if viewModel.assets.isEmpty {
        emptyStateView
      } else {
        assetListContent
      }
    }
    .navigationTitle(viewModel.portfolio.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Add Asset") {
          // TODO: Navigate to Asset creation screen
        }
        .accessibilityIdentifier("Add Asset")
      }
    }
  }

  // MARK: - Asset List Content

  private var assetListContent: some View {
    VStack(spacing: 0) {
      // Portfolio Summary Header
      portfolioSummaryHeader

      Divider()

      // Assets List
      List {
        ForEach(viewModel.assets) { asset in
          AssetRowView(asset: asset)
            .accessibilityIdentifier("Asset-\(asset.name)")
        }
      }
      .accessibilityIdentifier("Asset List")
    }
  }

  // MARK: - Portfolio Summary Header

  private var portfolioSummaryHeader: some View {
    VStack(spacing: 8) {
      HStack {
        Text("Total Value")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      HStack {
        Text(viewModel.totalValue.formatted(currency: viewModel.portfolio.name))
          .font(.largeTitle)
          .fontWeight(.bold)
        Spacer()
      }

      if let description = viewModel.portfolio.portfolioDescription {
        HStack {
          Text(description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
        }
      }
    }
    .padding()
    .background(Color(.secondarySystemFill))
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
        // TODO: Navigate to Asset creation screen
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

        Text(asset.assetType.rawValue)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(asset.assetType.rawValue)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text(asset.currentValue.formatted(currency: asset.currency))
          .font(.body)
          .fontWeight(.medium)

        HStack(spacing: 4) {
          Text("Qty:")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(asset.quantity.formatted())
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

  let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

  return NavigationStack {
    PortfolioDetailView(viewModel: viewModel)
  }
  .modelContainer(container)
}

#Preview("Empty Portfolio") {
  let container = PreviewContainer.container
  let context = container.mainContext

  let portfolio = Portfolio(name: "Empty Portfolio", portfolioDescription: "No assets yet")
  context.insert(portfolio)

  let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

  return NavigationStack {
    PortfolioDetailView(viewModel: viewModel)
  }
  .modelContainer(container)
}

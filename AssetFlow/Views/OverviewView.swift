//
//  OverviewView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

/// Overview View - Default landing page showing portfolio summary
///
/// Primary platform: macOS
/// This view provides a high-level overview of all portfolios and total wealth.
struct OverviewView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Portfolio.name) private var portfolios: [Portfolio]

  @State private var showingAddPortfolioSheet = false
  @State private var exchangeRateService = ExchangeRateService.shared
  @State private var isLoadingRates = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        // Total Value Card
        totalValueCard

        // Portfolio Summary
        if !portfolios.isEmpty {
          portfolioSummarySection
        }
      }
      .padding()
    }
    .navigationTitle("Overview")
    .task {
      await exchangeRateService.fetchRates()
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingAddPortfolioSheet = true
        } label: {
          Label("Add Portfolio", systemImage: "plus")
        }
        .help("Add Portfolio")
        .accessibilityIdentifier("Add Portfolio Overview")
      }
    }
    .sheet(isPresented: $showingAddPortfolioSheet) {
      NavigationStack {
        let formViewModel = PortfolioFormViewModel(modelContext: modelContext)
        PortfolioFormView(viewModel: formViewModel)
      }
    }
  }

  // MARK: - Total Value Card

  private var totalValueCard: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Total Portfolio Value")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      HStack {
        Text(totalValue.formatted(currency: "USD"))
          .font(.system(size: 48, weight: .bold))
          .accessibilityIdentifier("Total Portfolio Value")
        Spacer()
      }

      HStack {
        Label("\(portfolios.count) Portfolios", systemImage: "folder.fill")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }
    .padding(24)
    .background(Color(.secondarySystemFill))
    .cornerRadius(12)
  }

  // MARK: - Portfolio Summary Section

  private var portfolioSummarySection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Portfolios")
        .font(.title2)
        .fontWeight(.semibold)

      VStack(spacing: 12) {
        ForEach(portfolios) { portfolio in
          PortfolioSummaryRow(portfolio: portfolio, exchangeRateService: exchangeRateService)
        }
      }
    }
  }

  // MARK: - Computed Properties

  private var totalValue: Decimal {
    portfolios.reduce(0) { total, portfolio in
      total
        + PortfolioValueCalculator.calculateTotalValue(
          for: portfolio.assets ?? [],
          using: exchangeRateService.rates,
          targetCurrency: "USD",
          ratesBaseCurrency: exchangeRateService.baseCurrency
        )
    }
  }
}

// MARK: - Portfolio Summary Row

private struct PortfolioSummaryRow: View {
  let portfolio: Portfolio
  let exchangeRateService: ExchangeRateService

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(portfolio.name)
          .font(.headline)

        Text("\(portfolio.assetCount) assets")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(
        PortfolioValueCalculator.calculateTotalValue(
          for: portfolio.assets ?? [],
          using: exchangeRateService.rates,
          targetCurrency: "USD",
          ratesBaseCurrency: exchangeRateService.baseCurrency
        ).formatted(currency: "USD")
      )
      .font(.body)
      .fontWeight(.medium)
    }
    .padding(16)
    .background(Color(.tertiarySystemFill))
    .cornerRadius(8)
  }
}

// MARK: - Previews

#Preview("With Portfolios") {
  let container = PreviewContainer.container
  let context = container.mainContext

  // Create portfolios with assets
  let tech = Portfolio(name: "Tech Portfolio", portfolioDescription: "High-growth tech stocks")
  context.insert(tech)
  let apple = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: tech)
  context.insert(apple)
  context.insert(PriceHistory(date: Date(), price: 150.0, asset: apple))
  context.insert(
    Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 100.0,
      totalAmount: 1000.0, asset: apple))

  let crypto = Portfolio(name: "Crypto", portfolioDescription: "Digital assets")
  context.insert(crypto)

  return NavigationStack {
    OverviewView()
  }
  .modelContainer(container)
}

#Preview("Empty") {
  let container = PreviewContainer.container

  return NavigationStack {
    OverviewView()
  }
  .modelContainer(container)
}

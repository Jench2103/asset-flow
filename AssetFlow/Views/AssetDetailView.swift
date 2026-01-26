//
//  AssetDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/20.
//

import SwiftData
import SwiftUI

/// Asset Detail View - Displays comprehensive information about an asset.
///
/// Shows value card with current price and date, performance card,
/// and actions section with "View Price History" button.
struct AssetDetailView: View {
  let asset: Asset
  @Environment(\.modelContext) private var modelContext
  @State private var showingPriceHistory = false
  @State private var showingTransactionHistory = false
  @State private var showingAddTransaction = false

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Value Card
        valueCard

        // Performance Card
        performanceCard

        // Actions Section
        actionsSection

        // Notes
        if let notes = asset.notes, !notes.isEmpty {
          notesSection(notes: notes)
        }
      }
      .padding()
    }
    .navigationTitle(asset.name)
    #if os(macOS)
      .navigationSubtitle(asset.assetType.rawValue)
    #endif
    .sheet(isPresented: $showingPriceHistory) {
      NavigationStack {
        PriceHistoryView(
          asset: asset,
          managementViewModel: PriceHistoryManagementViewModel(
            asset: asset, modelContext: modelContext)
        )
      }
    }
    .sheet(isPresented: $showingTransactionHistory) {
      NavigationStack {
        TransactionHistoryView(
          asset: asset,
          viewModel: TransactionHistoryViewModel(asset: asset)
        )
      }
    }
    .sheet(isPresented: $showingAddTransaction) {
      NavigationStack {
        TransactionFormView(
          viewModel: TransactionFormViewModel(
            modelContext: modelContext, asset: asset)
        )
      }
    }
  }

  // MARK: - Value Card

  private var valueCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "banknote")
          .font(.title2)
          .foregroundStyle(.blue)
        Text("Value")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      // Current Value
      Text(asset.currentValue.formatted(currency: asset.currency))
        .font(.system(size: 32, weight: .bold))
        .foregroundStyle(.primary)

      // Current Price + Date
      HStack(spacing: 4) {
        Text("Price:")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Text(asset.currentPrice.formatted(currency: asset.currency))
          .font(.subheadline)
          .fontWeight(.medium)

        if let priceDate = asset.currentPriceDate {
          Text("(Updated: \(priceDate.formattedDate))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
          Text("(No price recorded)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      // Quantity (hidden for cash)
      if asset.assetType != .cash {
        Divider()

        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Quantity")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(asset.quantity.formatted())
              .font(.body)
              .fontWeight(.medium)
          }

          VStack(alignment: .leading, spacing: 2) {
            Text("Avg. Cost")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(asset.averageCost.formatted(currency: asset.currency))
              .font(.body)
              .fontWeight(.medium)
          }

          VStack(alignment: .leading, spacing: 2) {
            Text("Cost Basis")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(asset.costBasis.formatted(currency: asset.currency))
              .font(.body)
              .fontWeight(.medium)
          }
        }
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
  }

  // MARK: - Performance Card

  private var performanceCard: some View {
    let unrealizedGain = asset.currentValue - asset.costBasis
    let gainPercentage: Decimal =
      asset.costBasis > 0 ? (unrealizedGain / asset.costBasis) * 100 : 0

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "chart.line.uptrend.xyaxis")
          .font(.title2)
          .foregroundStyle(.blue)
        Text("Performance")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Unrealized Gain/Loss")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          Text(unrealizedGain.formatted(currency: asset.currency))
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundStyle(unrealizedGain >= 0 ? .green : .red)

          Text("(\(gainPercentage.formattedPercentage()))")
            .font(.body)
            .foregroundStyle(unrealizedGain >= 0 ? .green : .red)
        }
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
  }

  // MARK: - Actions Section

  private var actionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "gearshape")
          .font(.title2)
          .foregroundStyle(.blue)
        Text("Actions")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      Button {
        showingPriceHistory = true
      } label: {
        Label("View Price History", systemImage: "chart.line.uptrend.xyaxis")
      }
      .buttonStyle(.borderedProminent)

      Button {
        showingTransactionHistory = true
      } label: {
        Label("View Transaction History", systemImage: "list.bullet.rectangle")
      }
      .buttonStyle(.borderedProminent)

      Button {
        showingAddTransaction = true
      } label: {
        Label("Record Transaction", systemImage: "plus.circle")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
  }

  // MARK: - Notes Section

  private func notesSection(notes: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "note.text")
          .font(.title2)
          .foregroundStyle(.orange)
        Text("Notes")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }

      Text(notes)
        .font(.body)
        .foregroundStyle(.primary)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
  }
}

//
//  TransactionHistoryView.swift
//  AssetFlow
//
//  Created by Claude on 2026/1/26.
//

import SwiftData
import SwiftUI

/// Transaction History View - Displays a chronological list of transactions for an asset.
///
/// Primary platform: macOS (uses Table component)
/// Shows asset info header, transaction table with type, date, quantity, and total amount.
struct TransactionHistoryView: View {
  let asset: Asset
  @State var viewModel: TransactionHistoryViewModel
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var showingAddTransaction = false

  var body: some View {
    VStack(spacing: 0) {
      assetInfoHeader

      if viewModel.sortedTransactions.isEmpty {
        emptyStateView
      } else {
        transactionContent
      }
    }
    .navigationTitle("Transaction History - \(asset.name)")
    #if os(macOS)
      .frame(minWidth: 600, minHeight: 400)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") {
          dismiss()
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingAddTransaction = true
        } label: {
          Label("Record Transaction", systemImage: "plus")
        }
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

  // MARK: - Asset Info Header

  private var assetInfoHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(asset.name)
            .font(.title2)
            .fontWeight(.semibold)

          HStack(spacing: 8) {
            Text(asset.assetType.rawValue)
              .font(.subheadline)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(Color.blue.opacity(0.1))
              )

            Text(asset.currency)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text(asset.currentPrice.formatted(currency: asset.currency))
            .font(.title3)
            .fontWeight(.medium)

          Text("\(viewModel.transactionCount) transaction(s)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.controlBackgroundColor))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
    .padding(.horizontal)
    .padding(.top, 8)
  }

  // MARK: - Transaction Content

  private var transactionContent: some View {
    #if os(macOS)
      Table(viewModel.sortedTransactions) {
        TableColumn("Type") { transaction in
          Text(transactionDisplayName(for: transaction.transactionType))
        }
        TableColumn("Date") { transaction in
          Text(transaction.transactionDate.formattedDate)
        }
        TableColumn("Quantity") { transaction in
          Text(transaction.quantity.formatted())
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        TableColumn("Total Amount") { transaction in
          Text(transaction.totalAmount.formatted(currency: asset.currency))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    #else
      List(viewModel.sortedTransactions) { transaction in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(transactionDisplayName(for: transaction.transactionType))
              .fontWeight(.medium)
            Spacer()
            Text(transaction.transactionDate.formattedDate)
              .foregroundStyle(.secondary)
          }
          HStack {
            Text("Qty: \(transaction.quantity.formatted())")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Text(transaction.totalAmount.formatted(currency: asset.currency))
              .font(.subheadline)
              .fontWeight(.medium)
          }
        }
      }
    #endif
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "list.bullet.rectangle")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text("No transactions yet")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Record your first transaction for this asset")
          .font(.body)
          .foregroundStyle(.secondary)
      }

      Button {
        showingAddTransaction = true
      } label: {
        Label("Record Transaction", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Helpers

  private func transactionDisplayName(for type: TransactionType) -> String {
    if asset.assetType == .cash {
      switch type {
      case .buy: return "Deposit"
      case .sell: return "Withdrawal"
      default: return type.rawValue
      }
    }
    return type.rawValue
  }
}

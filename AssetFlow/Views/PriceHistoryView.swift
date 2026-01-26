//
//  PriceHistoryView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/20.
//

import SwiftData
import SwiftUI

/// Price History View - Displays and manages historical price records for an asset.
///
/// Primary platform: macOS (uses Table component)
/// Shows asset info header, price history table with context menu actions,
/// and provides add/edit/delete functionality.
struct PriceHistoryView: View {
  let asset: Asset
  @State var managementViewModel: PriceHistoryManagementViewModel
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  @State private var selectedRecordID: PriceHistory.ID?
  @State private var showingAddRecord = false
  @State private var editingRecord: PriceHistory?

  var body: some View {
    VStack(spacing: 0) {
      // Asset Info Header
      assetInfoHeader

      // Price History Table
      if managementViewModel.sortedPriceHistory.isEmpty {
        emptyStateView
      } else {
        priceHistoryContent
      }
    }
    .navigationTitle("Price History - \(asset.name)")
    #if os(macOS)
      .frame(minWidth: 500, minHeight: 400)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") {
          dismiss()
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          showingAddRecord = true
        } label: {
          Label("Add Price Record", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAddRecord) {
      NavigationStack {
        PriceHistoryFormView(
          viewModel: PriceHistoryFormViewModel(
            modelContext: modelContext, asset: asset)
        )
      }
    }
    .sheet(item: $editingRecord) { record in
      NavigationStack {
        PriceHistoryFormView(
          viewModel: PriceHistoryFormViewModel(
            modelContext: modelContext, asset: asset, priceHistory: record)
        )
      }
    }
    .confirmationDialog(
      "Delete Price Record",
      isPresented: $managementViewModel.showingDeleteConfirmation,
      presenting: managementViewModel.recordToDelete,
      actions: { _ in
        Button("Delete", role: .destructive) {
          managementViewModel.confirmDelete()
        }
        Button("Cancel", role: .cancel) {
          managementViewModel.cancelDelete()
        }
      },
      message: { record in
        Text(
          "Are you sure you want to delete the price record from \(record.date.formattedDate)?"
        )
      }
    )
    .alert(
      "Cannot Delete Last Price Record",
      isPresented: $managementViewModel.showingLastRecordAlert,
      actions: {
        Button("OK") {
          managementViewModel.showingLastRecordAlert = false
        }
      },
      message: {
        Text(
          "An asset must have at least one price record."
            + "\n\nYou can edit this record to update the price,"
            + " or delete the entire asset if no longer needed."
        )
      }
    )
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

  // MARK: - Price History Content

  private var priceHistoryContent: some View {
    #if os(macOS)
      Table(managementViewModel.sortedPriceHistory, selection: $selectedRecordID) {
        TableColumn("Date") { record in
          Text(record.date.formattedDate)
        }
        TableColumn("Price") { record in
          Text(record.price.formatted(currency: asset.currency))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
      .contextMenu(forSelectionType: PriceHistory.ID.self) { selectedIDs in
        if let selectedID = selectedIDs.first,
          let record = managementViewModel.sortedPriceHistory.first(where: {
            $0.id == selectedID
          })
        {
          Button {
            editingRecord = record
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button(role: .destructive) {
            managementViewModel.initiateDelete(record: record)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    #else
      List(managementViewModel.sortedPriceHistory) { record in
        HStack {
          Text(record.date.formattedDate)
          Spacer()
          Text(record.price.formatted(currency: asset.currency))
            .fontWeight(.medium)
        }
        .contextMenu {
          Button {
            editingRecord = record
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button(role: .destructive) {
            managementViewModel.initiateDelete(record: record)
          } label: {
            Label("Delete", systemImage: "trash")
          }
        }
      }
    #endif
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)

      VStack(spacing: 8) {
        Text("No price history yet")
          .font(.title2)
          .fontWeight(.semibold)

        Text("Add your first price record for this asset")
          .font(.body)
          .foregroundStyle(.secondary)
      }

      Button {
        showingAddRecord = true
      } label: {
        Label("Add Price Record", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

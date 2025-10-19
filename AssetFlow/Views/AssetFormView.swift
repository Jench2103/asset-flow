//
//  AssetFormView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

/// A view that presents a form for creating or editing an asset.
///
/// This view binds to an `AssetFormViewModel` to manage its state,
/// handle user input, and perform validation.
struct AssetFormView: View {
  /// The ViewModel that manages the form's state and logic.
  @State var viewModel: AssetFormViewModel
  /// The presentation mode environment value, used to dismiss the view.
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      // MARK: - Asset Details Section
      Section {
        VStack(alignment: .leading, spacing: 16) {
          // Name field
          VStack(alignment: .leading, spacing: 4) {
            TextField("Name", text: $viewModel.name)

            // Show validation messages after user interaction
            if viewModel.hasUserInteracted {
              if let validationMessage = viewModel.nameValidationMessage {
                Text(validationMessage)
                  .font(.caption)
                  .foregroundStyle(.red)
              }
            }
          }

          Divider()

          // Asset type picker
          VStack(alignment: .leading, spacing: 4) {
            Picker("Asset Type", selection: $viewModel.assetType) {
              ForEach(AssetType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
              }
            }
            .disabled(!viewModel.canEditAssetType)

            if !viewModel.canEditAssetType {
              Text("Cannot change asset type after transactions or price history are added.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Divider()

          // Currency picker
          VStack(alignment: .leading, spacing: 4) {
            Picker("Currency", selection: $viewModel.currency) {
              ForEach(CurrencyService.shared.currencies) { currency in
                Text(currency.displayName).tag(currency.code)
              }
            }
            .disabled(!viewModel.canEditCurrency)

            if !viewModel.canEditCurrency {
              Text("Cannot change currency after transactions or price history are added.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.vertical, 8)
      } header: {
        HStack {
          Image(systemName: "doc.text")
            .foregroundStyle(.blue)
          Text("Asset Details")
            .font(.headline)
            .foregroundStyle(.primary)
        }
        .textCase(nil)
        .padding(.bottom, 4)
      }
      .listRowBackground(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(.controlBackgroundColor).opacity(0.5))
      )

      // MARK: - Initial Position Section (new assets only)
      if !viewModel.isEditing {
        Section {
          VStack(alignment: .leading, spacing: 16) {
            if viewModel.assetType == .cash {
              // For cash assets, only show amount field
              VStack(alignment: .leading, spacing: 4) {
                TextField("Amount", text: $viewModel.quantity)
                  #if os(iOS)
                    .keyboardType(.decimalPad)
                  #endif

                if viewModel.hasQuantityInteraction {
                  if let validationMessage = viewModel.quantityValidationMessage {
                    Text(validationMessage)
                      .font(.caption)
                      .foregroundStyle(.red)
                  }
                }
              }
            } else {
              // For non-cash assets, show quantity and price
              // Quantity field
              VStack(alignment: .leading, spacing: 4) {
                TextField("Quantity", text: $viewModel.quantity)
                  #if os(iOS)
                    .keyboardType(.decimalPad)
                  #endif

                if viewModel.hasQuantityInteraction {
                  if let validationMessage = viewModel.quantityValidationMessage {
                    Text(validationMessage)
                      .font(.caption)
                      .foregroundStyle(.red)
                  }
                }
              }

              Divider()

              // Current value/price field
              VStack(alignment: .leading, spacing: 4) {
                TextField("Current Price", text: $viewModel.currentValue)
                  #if os(iOS)
                    .keyboardType(.decimalPad)
                  #endif

                if viewModel.hasCurrentValueInteraction {
                  if let validationMessage = viewModel.currentValueValidationMessage {
                    Text(validationMessage)
                      .font(.caption)
                      .foregroundStyle(.red)
                  }
                }
              }
            }
          }
          .padding(.vertical, 8)
        } header: {
          HStack {
            Image(systemName: "chart.bar.fill")
              .foregroundStyle(.green)
            Text("Initial Position")
              .font(.headline)
              .foregroundStyle(.primary)
          }
          .textCase(nil)
          .padding(.bottom, 4)
        }
        .listRowBackground(
          RoundedRectangle(cornerRadius: 8)
            .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
      }

      // MARK: - Notes Section
      Section {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
            .lineLimit(3...)
        }
        .padding(.vertical, 8)
      } header: {
        HStack {
          Image(systemName: "note.text")
            .foregroundStyle(.orange)
          Text("Notes")
            .font(.headline)
            .foregroundStyle(.primary)
        }
        .textCase(nil)
        .padding(.bottom, 4)
      }
      .listRowBackground(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(.controlBackgroundColor).opacity(0.5))
      )
    }
    .formStyle(.grouped)
    .navigationTitle(viewModel.isEditing ? "Edit Asset" : "New Asset")
    #if os(macOS)
      .padding()
      .frame(minWidth: 400, minHeight: 300)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          viewModel.save()
          dismiss()
        }
        .disabled(viewModel.isSaveDisabled)
      }
    }
  }
}

// MARK: - Previews

#Preview("New Asset") {
  let context = PreviewContainer.container.mainContext
  let portfolio = Portfolio(name: "Tech Portfolio")
  context.insert(portfolio)

  let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

  return NavigationStack {
    AssetFormView(viewModel: viewModel)
  }
  .modelContainer(PreviewContainer.container)
}

#Preview("Editing Asset") {
  let context = PreviewContainer.container.mainContext
  let portfolio = Portfolio(name: "Tech Portfolio")
  context.insert(portfolio)

  let asset = Asset(
    name: "Apple Inc.",
    assetType: .stock,
    currency: "USD",
    notes: "Tech stock",
    portfolio: portfolio
  )
  context.insert(asset)

  // Add transaction for quantity
  let transaction = Transaction(
    transactionType: .buy,
    transactionDate: Date(),
    quantity: 10,
    pricePerUnit: 150.0,
    totalAmount: 1500.0,
    asset: asset
  )
  context.insert(transaction)

  // Add price history
  let priceHistory = PriceHistory(date: Date(), price: 175.0, asset: asset)
  context.insert(priceHistory)

  let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio, asset: asset)

  return NavigationStack {
    AssetFormView(viewModel: viewModel)
  }
  .modelContainer(PreviewContainer.container)
}

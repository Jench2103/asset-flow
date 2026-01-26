//
//  TransactionFormView.swift
//  AssetFlow
//
//  Created by Claude on 2026/1/26.
//

import SwiftData
import SwiftUI

/// A view that presents a form for recording a new transaction.
///
/// This view binds to a `TransactionFormViewModel` to manage its state,
/// handle user input, and perform validation.
struct TransactionFormView: View {
  @State var viewModel: TransactionFormViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      // MARK: - Transaction Details Section
      Section {
        VStack(alignment: .leading, spacing: 16) {
          // Transaction Type Picker
          Picker("Type", selection: $viewModel.transactionType) {
            ForEach(TransactionType.allCases, id: \.self) { type in
              Text(viewModel.displayName(for: type)).tag(type)
            }
          }

          Divider()

          // Date Picker
          VStack(alignment: .leading, spacing: 4) {
            DatePicker(
              "Date",
              selection: $viewModel.transactionDate,
              displayedComponents: .date
            )

            if viewModel.hasDateInteraction {
              if let validationMessage = viewModel.dateValidationMessage {
                Text(validationMessage)
                  .font(.caption)
                  .foregroundStyle(.red)
              }
            }
          }

          Divider()

          // Quantity / Amount Field
          VStack(alignment: .leading, spacing: 4) {
            TextField(
              viewModel.isCashAsset ? "Amount" : "Quantity",
              text: $viewModel.quantityText
            )
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

          if !viewModel.isCashAsset {
            Divider()

            // Price Per Unit Field (hidden for cash assets)
            VStack(alignment: .leading, spacing: 4) {
              TextField(
                "Price per Unit (\(viewModel.asset.currency))",
                text: $viewModel.pricePerUnitText
              )
              #if os(iOS)
                .keyboardType(.decimalPad)
              #endif

              if viewModel.hasPricePerUnitInteraction {
                if let validationMessage = viewModel.pricePerUnitValidationMessage {
                  Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                }
              }
            }

            Divider()

            // Calculated Total Amount (Read-only, hidden for cash since total = amount)
            HStack {
              Text("Total Amount")
                .foregroundStyle(.secondary)
              Spacer()
              if let total = viewModel.calculatedTotalAmount {
                Text(total.formatted(currency: viewModel.asset.currency))
                  .fontWeight(.medium)
              } else {
                Text("\u{2014}")
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .padding(.vertical, 8)
      } header: {
        HStack {
          Image(systemName: "arrow.left.arrow.right")
            .foregroundStyle(.blue)
          Text("Transaction Details")
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
    .navigationTitle("Record Transaction")
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

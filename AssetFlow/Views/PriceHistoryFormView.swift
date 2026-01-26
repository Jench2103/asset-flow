//
//  PriceHistoryFormView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/20.
//

import SwiftData
import SwiftUI

/// A view that presents a form for creating or editing a price history record.
///
/// This view binds to a `PriceHistoryFormViewModel` to manage its state,
/// handle user input, and perform validation.
struct PriceHistoryFormView: View {
  /// The ViewModel that manages the form's state and logic.
  @State var viewModel: PriceHistoryFormViewModel
  /// The presentation mode environment value, used to dismiss the view.
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      // MARK: - Price Record Section
      Section {
        VStack(alignment: .leading, spacing: 16) {
          // Date picker
          VStack(alignment: .leading, spacing: 4) {
            DatePicker(
              "Date",
              selection: $viewModel.date,
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

          // Price field
          VStack(alignment: .leading, spacing: 4) {
            TextField(
              "Price (\(viewModel.asset.currency))",
              text: $viewModel.priceText
            )
            #if os(iOS)
              .keyboardType(.decimalPad)
            #endif

            if viewModel.hasPriceInteraction {
              if let validationMessage = viewModel.priceValidationMessage {
                Text(validationMessage)
                  .font(.caption)
                  .foregroundStyle(.red)
              }
            }
          }
        }
        .padding(.vertical, 8)
      } header: {
        HStack {
          Image(systemName: "chart.line.uptrend.xyaxis")
            .foregroundStyle(.blue)
          Text("Price Record")
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
    .navigationTitle(viewModel.navigationTitle)
    #if os(macOS)
      .padding()
      .frame(minWidth: 350, minHeight: 200)
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

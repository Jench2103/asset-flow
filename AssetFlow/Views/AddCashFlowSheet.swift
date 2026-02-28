//
//  AddCashFlowSheet.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
//

import SwiftUI

// MARK: - Add Cash Flow Sheet

struct AddCashFlowSheet: View {
  let viewModel: SnapshotDetailViewModel
  let onComplete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?
  enum Field { case description, amount }

  @State private var description = ""
  @State private var amountText = ""
  @State private var cashFlowCurrency = SettingsService.shared.mainCurrency
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    NavigationStack {
      Form {
        TextField("Description", text: $description)
          .focused($focusedField, equals: .description)
          .accessibilityIdentifier("Cash Flow Description Field")

        TextField("Amount (positive = inflow, negative = outflow)", text: $amountText)
          .focused($focusedField, equals: .amount)
          .accessibilityIdentifier("Cash Flow Amount Field")

        Picker("Currency", selection: $cashFlowCurrency) {
          ForEach(CurrencyService.shared.currencies) { currency in
            Text(currency.displayName).tag(currency.code)
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle("Add Cash Flow")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add") {
            addCashFlow()
          }
          .disabled(
            description.trimmingCharacters(in: .whitespaces).isEmpty
              || Decimal(string: amountText) == nil
          )
        }
      }
    }
    .frame(minWidth: 350, minHeight: 180)
    .onAppear { focusedField = .description }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private func addCashFlow() {
    guard let amount = Decimal(string: amountText) else { return }
    do {
      try viewModel.addCashFlow(
        description: description, amount: amount, currency: cashFlowCurrency)
      onComplete()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

// MARK: - Edit Cash Flow Popover

struct EditCashFlowPopover: View {
  let currentDescription: String
  let currentAmount: Decimal
  let onSave: (String, Decimal) -> Void
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?
  enum Field { case description, amount }
  @State private var description: String
  @State private var amountText: String

  init(
    currentDescription: String,
    currentAmount: Decimal,
    onSave: @escaping (String, Decimal) -> Void
  ) {
    self.currentDescription = currentDescription
    self.currentAmount = currentAmount
    self.onSave = onSave
    _description = State(wrappedValue: currentDescription)
    _amountText = State(wrappedValue: NSDecimalNumber(decimal: currentAmount).stringValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Edit Cash Flow").font(.headline)
      TextField("Description", text: $description)
        .textFieldStyle(.roundedBorder)
        .focused($focusedField, equals: .description)
      TextField("Amount", text: $amountText)
        .textFieldStyle(.roundedBorder)
        .focused($focusedField, equals: .amount)
        .onSubmit { saveIfValid() }
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save") { saveIfValid() }
          .keyboardShortcut(.defaultAction)
          .disabled(
            description.trimmingCharacters(in: .whitespaces).isEmpty
              || Decimal(string: amountText) == nil
          )
      }
    }
    .frame(width: 280)
    .padding()
    .onAppear { focusedField = .description }
  }

  private func saveIfValid() {
    let trimmed = description.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, let amount = Decimal(string: amountText) else { return }
    onSave(trimmed, amount)
    dismiss()
  }
}

//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI

// MARK: - Cash Flow Entry Row View

struct BulkEntryCashFlowRowView: View, Equatable {
  var viewModel: BulkEntryViewModel
  let row: BulkEntryCashFlowRow
  var focusedAmountRowID: FocusState<UUID?>.Binding
  var focusedDescriptionRowID: FocusState<UUID?>.Binding

  static func == (lhs: BulkEntryCashFlowRowView, rhs: BulkEntryCashFlowRowView) -> Bool {
    lhs.row == rhs.row
  }

  private enum CashFlowField {
    case description
    case amount
  }

  @State private var localDescription: String = ""
  @State private var localAmount: String = ""
  @FocusState private var focusedField: CashFlowField?

  var body: some View {
    let isExcluded = !row.isIncluded
    let localEmptyDescription =
      row.isIncluded
      && localDescription.trimmingCharacters(in: .whitespaces).isEmpty
    let localValidationError = !localAmount.isEmpty && Decimal(string: localAmount) == nil
    let localEmptyAmount =
      row.isIncluded && localAmount.trimmingCharacters(in: .whitespaces).isEmpty

    HStack(spacing: 8) {
      // Include toggle
      Toggle("", isOn: includeBinding)
        .labelsHidden()
        .accessibilityLabel("Include \(row.cashFlowDescription)")
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this cash flow from the snapshot")

      // Description + source badge
      HStack(spacing: 6) {
        TextField("Description", text: $localDescription)
          .textFieldStyle(.roundedBorder)
          .frame(minWidth: 150)
          .disabled(isExcluded)
          .focused(focusedDescriptionRowID, equals: row.id)
          .focused($focusedField, equals: .description)
          .onSubmit {
            commitDescription()
            focusedField = .amount
          }
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(
                localEmptyDescription ? .red : .clear,
                lineWidth: 1.5))
        sourceBadge
      }
      .frame(minWidth: 150, alignment: .leading)

      Spacer()

      // Amount field
      TextField("Enter amount", text: $localAmount)
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(width: 160)
        .multilineTextAlignment(.trailing)
        .disabled(isExcluded)
        .focused(focusedAmountRowID, equals: row.id)
        .focused($focusedField, equals: .amount)
        .onSubmit {
          commitAmount()
          viewModel.advanceCashFlowFocus(from: row.id)
        }
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              localValidationError || localEmptyAmount ? .red : .clear,
              lineWidth: 1.5))

      // Currency picker
      BulkEntryCurrencyPicker(selection: currencyBinding)
        .frame(width: 80)
        .disabled(isExcluded)

      // Delete button (only for manualNew)
      if row.source == .manualNew {
        Button {
          viewModel.removeCashFlowRow(rowID: row.id)
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .helpWhenUnlocked("Remove this cash flow")
        .frame(width: 28)
      } else {
        Spacer().frame(width: 28)
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
    .opacity(isExcluded ? 0.5 : 1.0)
    .accessibilityLabel(
      "\(row.cashFlowDescription), \(localAmount), \(row.isIncluded ? "included" : "excluded")"
    )
    .onAppear {
      localDescription = row.cashFlowDescription
      localAmount = row.amountText
    }
    .onDisappear {
      commitDescription()
      commitAmount()
    }
    .onChange(of: row.cashFlowDescription) { _, newValue in
      localDescription = newValue
    }
    .onChange(of: row.amountText) { _, newValue in
      localAmount = newValue
    }
    .onChange(of: row.commitSequence) { _, _ in
      commitDescription()
      commitAmount()
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var sourceBadge: some View {
    if row.source == .csv {
      Text("CSV")
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.blue.opacity(0.15), in: Capsule())
        .foregroundStyle(.blue)
    }
  }

  // MARK: - Local State Commits

  private func commitDescription() {
    if let index = viewModel.cashFlowRows.firstIndex(where: { $0.id == row.id }),
      viewModel.cashFlowRows[index].cashFlowDescription != localDescription
    {
      viewModel.cashFlowRows[index].cashFlowDescription = localDescription
    }
  }

  private func commitAmount() {
    if let index = viewModel.cashFlowRows.firstIndex(where: { $0.id == row.id }),
      viewModel.cashFlowRows[index].amountText != localAmount
    {
      viewModel.cashFlowRows[index].amountText = localAmount
    }
  }

  // MARK: - Bindings

  private var includeBinding: Binding<Bool> {
    Binding(
      get: { row.isIncluded },
      set: { _ in viewModel.toggleCashFlowInclude(rowID: row.id) })
  }

  private var currencyBinding: Binding<String> {
    Binding(
      get: { row.currency },
      set: { newValue in
        if let index = viewModel.cashFlowRows.firstIndex(where: { $0.id == row.id }) {
          viewModel.cashFlowRows[index].currency = newValue
        }
      })
  }
}

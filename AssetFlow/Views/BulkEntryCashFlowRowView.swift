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
    let localValidationError = !localAmount.isEmpty && Decimal.parse(localAmount) == nil
    let localEmptyAmount =
      row.isIncluded && localAmount.trimmingCharacters(in: .whitespaces).isEmpty

    let cellStyle = BulkEntryRowCellStyle()

    GridRow {
      // Include toggle
      Toggle("", isOn: includeBinding)
        .labelsHidden()
        .accessibilityLabel("Include \(row.cashFlowDescription)")
        .helpWhenUnlocked("Include or exclude this cash flow from the snapshot")
        .modifier(cellStyle)

      // `.frame(maxWidth: .infinity)` makes this the flex column.
      // `TextField`'s natural width is independent of its text, so
      // typing does not reflow the column.
      HStack(spacing: 6) {
        TextField("Description", text: $localDescription)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: .infinity)
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
      .modifier(cellStyle)

      // Fixed 160pt width — letting this `TextField` flex with content
      // would reflow the entire column on every keystroke.
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
              lineWidth: 1.5)
        )
        .modifier(cellStyle)

      BulkEntryCurrencyPicker(selection: currencyBinding)
        .disabled(isExcluded)
        .modifier(cellStyle)

      Group {
        if row.source == .manualNew {
          Button {
            viewModel.removeCashFlowRow(rowID: row.id)
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(.red)
          }
          .buttonStyle(.plain)
          .helpWhenUnlocked("Remove this cash flow")
        } else {
          Color.clear
            .frame(width: 1, height: 1)
        }
      }
      .frame(width: 28)
      .modifier(cellStyle)
    }
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
    .onChange(of: localDescription) { _, newValue in
      viewModel.setPendingCashFlowDescription(row.id, to: newValue)
    }
    .onChange(of: localAmount) { _, newValue in
      viewModel.setPendingCashFlowAmount(row.id, to: newValue)
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
    viewModel.updateCashFlowDescription(row.id, to: localDescription)
  }

  private func commitAmount() {
    viewModel.updateCashFlowAmount(row.id, to: localAmount)
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
      set: { newValue in viewModel.updateCashFlowCurrency(row.id, to: newValue) })
  }
}

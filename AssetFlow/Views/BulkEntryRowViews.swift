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

// MARK: - Asset Entry Row View

struct BulkEntryRowView: View, Equatable {
  var viewModel: BulkEntryViewModel
  let row: BulkEntryRow
  @Binding var cachedCategoryNames: [String]
  var focusedRowID: FocusState<UUID?>.Binding
  var nameFieldFocusedRowID: FocusState<UUID?>.Binding

  static func == (lhs: BulkEntryRowView, rhs: BulkEntryRowView) -> Bool {
    lhs.row == rhs.row && lhs.cachedCategoryNames == rhs.cachedCategoryNames
  }

  @State private var localValueText: String = ""
  @State private var localAssetName: String = ""

  var body: some View {
    let isExcluded = !row.isIncluded
    let localIsUpdated =
      row.isIncluded && Decimal(string: localValueText) != nil
      && Decimal(string: localValueText) != Decimal(0)
    let localValidationError = !localValueText.isEmpty && Decimal(string: localValueText) == nil
    let localZeroValueError =
      row.isIncluded && Decimal(string: localValueText) == Decimal(0)

    HStack(spacing: 8) {
      Toggle("", isOn: includeBinding)
        .labelsHidden()
        .accessibilityLabel("Include \(row.assetName)")
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this asset from the snapshot")

      // Asset name column
      HStack(spacing: 6) {
        if row.isNewRow {
          TextField("Asset name", text: $localAssetName)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 100)
            .disabled(isExcluded)
            .focused(nameFieldFocusedRowID, equals: row.id)
            .onSubmit { commitAssetName() }
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(
                  row.isNewRow && localAssetName.trimmingCharacters(in: .whitespaces).isEmpty
                    ? .red : .clear,
                  lineWidth: 1.5)
            )
        } else {
          Text(row.assetName)
            .strikethrough(isExcluded)
        }
        sourceBadge
      }
      .frame(minWidth: 120, alignment: .leading)

      Spacer()

      // Category column
      if row.isNewAsset {
        BulkEntryCategoryPicker(
          categoryName: categoryNameBinding,
          cachedNames: $cachedCategoryNames
        )
        .frame(width: 120)
      } else {
        Text(row.asset?.category?.name ?? "\u{2014}")
          .font(.callout)
          .foregroundStyle(row.asset?.category != nil ? .primary : .secondary)
          .frame(width: 120, alignment: .center)
      }

      // Currency column
      if row.isNewRow {
        BulkEntryCurrencyPicker(selection: currencyBinding)
          .frame(width: 80)
      } else {
        Text(row.currency.uppercased())
          .font(.callout)
          .frame(width: 80, alignment: .center)
      }

      Text(row.previousValue?.formatted(currency: row.currency) ?? "\u{2014}")
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .trailing)

      TextField("Enter value\u{2026}", text: $localValueText)
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(width: 160)
        .multilineTextAlignment(.trailing)
        .focused(focusedRowID, equals: row.id)
        .onSubmit {
          commitValue()
          viewModel.advanceFocus(from: row.id)
        }
        .disabled(isExcluded)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              (localValidationError || localZeroValueError) ? .red : .clear,
              lineWidth: 1.5)
        )
        .helpWhenUnlocked(
          localZeroValueError
            ? LocalizedStringKey(
              "Value cannot be 0. Exclude the asset instead if it is no longer held.")
            : nil
        )

      // Delete button for manualNew rows, padding for others
      if row.isNewRow {
        Button {
          viewModel.removeManualRow(rowID: row.id)
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .helpWhenUnlocked("Remove this manually added asset")
        .frame(width: 28)
      } else {
        Spacer()
          .frame(width: 28)
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
    .background(
      localIsUpdated
        ? Color.green.opacity(0.06)
        : Color.clear
    )
    .opacity(isExcluded ? 0.5 : 1.0)
    .accessibilityLabel(
      "\(row.assetName), \(row.platform), \(row.isUpdated ? "updated" : row.isPending ? "pending" : "excluded")"
    )
    .onAppear {
      localValueText = row.newValueText
      localAssetName = row.assetName
    }
    .onChange(of: row.newValueText) { _, newValue in
      localValueText = newValue
    }
    .onChange(of: row.assetName) { _, newValue in
      localAssetName = newValue
    }
    .onChange(of: focusedRowID.wrappedValue) { oldValue, _ in
      if oldValue == row.id {
        commitValue()
      }
    }
    .onChange(of: nameFieldFocusedRowID.wrappedValue) { oldValue, _ in
      if oldValue == row.id {
        commitAssetName()
      }
    }
  }

  // MARK: - Source Badge

  @ViewBuilder
  private var sourceBadge: some View {
    if row.source == .csv {
      Text("CSV")
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.blue.opacity(0.15), in: Capsule())
        .foregroundStyle(.blue)
    } else if row.source == .manualNew {
      Text("NEW")
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.green.opacity(0.15), in: Capsule())
        .foregroundStyle(.green)
    }
  }

  // MARK: - Local State Commits

  private func commitValue() {
    if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }),
      viewModel.rows[index].newValueText != localValueText
    {
      viewModel.rows[index].newValueText = localValueText
    }
  }

  private func commitAssetName() {
    guard row.isNewRow else { return }
    if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }),
      viewModel.rows[index].assetName != localAssetName
    {
      viewModel.rows[index].assetName = localAssetName
    }
  }

  // MARK: - Bindings

  private var includeBinding: Binding<Bool> {
    Binding(
      get: { row.isIncluded },
      set: { _ in viewModel.toggleInclude(rowID: row.id) }
    )
  }

  private var currencyBinding: Binding<String> {
    Binding(
      get: { row.currency },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].currency = newValue
        }
      }
    )
  }

  private var categoryNameBinding: Binding<String> {
    Binding(
      get: { row.categoryName ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].categoryName = newValue.isEmpty ? nil : newValue
        }
      }
    )
  }
}

// MARK: - Category Name Picker

/// A lightweight picker for selecting or creating a category by name.
///
/// Unlike `CategoryPickerField`, this does not create `Category` objects
/// in the database. It stores category names as strings, deferring
/// database creation to snapshot save time.
struct BulkEntryCategoryPicker: View {
  @Binding var categoryName: String
  @Binding var cachedNames: [String]

  @State private var showNewField = false
  @State private var newName = ""

  var body: some View {
    if showNewField {
      HStack(spacing: 2) {
        TextField("Category", text: $newName)
          .textFieldStyle(.roundedBorder)
          .font(.callout)
          .onSubmit { commitNew() }
        Button {
          commitNew()
        } label: {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        Button {
          showNewField = false
          newName = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    } else {
      Picker("", selection: pickerBinding) {
        Text("None").tag("")
        ForEach(cachedNames, id: \.self) { name in
          Text(name).tag(name)
        }
        Divider()
        Text("New Category\u{2026}").tag("__new__")
      }
      .labelsHidden()
      .font(.callout)
    }
  }

  private var pickerBinding: Binding<String> {
    Binding(
      get: { categoryName },
      set: { newValue in
        if newValue == "__new__" {
          showNewField = true
          newName = ""
        } else {
          categoryName = newValue
        }
      }
    )
  }

  private func commitNew() {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    // Case-insensitive match against existing names
    if let match = cachedNames.first(where: { $0.lowercased() == trimmed.lowercased() }) {
      categoryName = match
    } else {
      categoryName = trimmed
      cachedNames.append(trimmed)
      cachedNames.sort()
    }

    showNewField = false
    newName = ""
  }
}

// MARK: - Currency Picker

/// An extracted currency picker that avoids rebuilding 340+ items on every parent re-render.
///
/// By isolating the `ForEach(CurrencyService.shared.currencies)` in its own `View` struct,
/// SwiftUI can skip re-diffing the picker content when only the parent's other state changes
/// (e.g., typing in a description field). The `@Binding` only triggers re-render when the
/// selected currency actually changes.
struct BulkEntryCurrencyPicker: View {
  @Binding var selection: String

  var body: some View {
    Picker("", selection: $selection) {
      ForEach(CurrencyService.shared.currencies) { currency in
        Text(currency.code).tag(currency.code)
      }
    }
    .labelsHidden()
  }
}

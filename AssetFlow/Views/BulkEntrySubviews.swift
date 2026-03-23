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

// MARK: - Progress Stats View

struct BulkEntryProgressStats: View {
  let updatedCount: Int
  let pendingCount: Int
  let excludedCount: Int

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
        Text("\(updatedCount) updated")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 4) {
        Circle()
          .fill(.orange)
          .frame(width: 8, height: 8)
        Text("\(pendingCount) pending")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 4) {
        Circle()
          .fill(.gray)
          .frame(width: 8, height: 8)
        Text("\(excludedCount) excluded")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Validation Warnings View

struct BulkEntryValidationWarnings: View {
  let zeroValueCount: Int
  let hasInvalidNewRows: Bool
  let hasDuplicateNames: Bool

  var body: some View {
    if zeroValueCount > 0 {
      Label(
        String(
          localized:
            "\(zeroValueCount) assets have a value of 0. Exclude them or enter a non-zero value.",
          table: "Snapshot"),
        systemImage: "exclamationmark.triangle.fill"
      )
      .font(.callout)
      .foregroundStyle(.red)
    }

    if hasInvalidNewRows {
      Label(
        String(
          localized: "Some new assets are missing a name.",
          table: "Snapshot"),
        systemImage: "exclamationmark.triangle.fill"
      )
      .font(.callout)
      .foregroundStyle(.red)
    }

    if hasDuplicateNames {
      Label(
        String(
          localized: "Duplicate asset names found within a platform.",
          table: "Snapshot"),
        systemImage: "exclamationmark.triangle.fill"
      )
      .font(.callout)
      .foregroundStyle(.red)
    }
  }
}

// MARK: - Column Headers View

struct BulkEntryColumnHeaders: View {
  var body: some View {
    HStack(spacing: 8) {
      Text("Include")
        .frame(width: 60, alignment: .center)
      Text("Asset Name")
        .frame(minWidth: 120, alignment: .leading)
      Spacer()
      Text("Category")
        .frame(width: 120, alignment: .center)
      Text("Currency")
        .frame(width: 80, alignment: .center)
      Text("Previous Value")
        .frame(width: 140, alignment: .trailing)
      Text("New Value")
        .frame(width: 160, alignment: .trailing)
      Spacer()
        .frame(width: 28)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.vertical, 4)
    .padding(.horizontal, 4)
    .background(.fill.quaternary)
  }
}

// MARK: - Asset Entry Row View

struct BulkEntryRowView: View {
  var viewModel: BulkEntryViewModel
  let row: BulkEntryRow
  let isDuplicate: Bool
  @Binding var cachedCategoryNames: [String]
  var focusedRowID: FocusState<UUID?>.Binding
  let onAdvanceFocus: () -> Void
  let onDelete: () -> Void

  var body: some View {
    let isExcluded = !row.isIncluded
    let isUpdated = row.isUpdated

    HStack(spacing: 8) {
      Toggle("", isOn: includeBinding)
        .labelsHidden()
        .accessibilityLabel("Include \(row.assetName)")
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this asset from the snapshot")

      // Asset name column
      HStack(spacing: 6) {
        if row.isNewRow {
          TextField("Asset name", text: assetNameBinding)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 100)
            .disabled(isExcluded)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(
                  (row.hasEmptyName || isDuplicate) ? .red : .clear,
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
        Picker("", selection: currencyBinding) {
          ForEach(CurrencyService.shared.currencies) { currency in
            Text(currency.code).tag(currency.code)
          }
        }
        .labelsHidden()
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

      TextField("Enter value\u{2026}", text: valueBinding)
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(width: 160)
        .multilineTextAlignment(.trailing)
        .focused(focusedRowID, equals: row.id)
        .onSubmit { onAdvanceFocus() }
        .disabled(isExcluded)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              (row.hasValidationError || row.hasZeroValueError) ? .red : .clear,
              lineWidth: 1.5)
        )
        .helpWhenUnlocked(
          row.hasZeroValueError
            ? LocalizedStringKey(
              "Value cannot be 0. Exclude the asset instead if it is no longer held.")
            : nil
        )

      // Delete button for manualNew rows, padding for others
      if row.isNewRow {
        Button {
          onDelete()
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
      isUpdated
        ? Color.green.opacity(0.06)
        : Color.clear
    )
    .opacity(isExcluded ? 0.5 : 1.0)
    .accessibilityLabel(
      "\(row.assetName), \(row.platform), \(row.isUpdated ? "updated" : row.isPending ? "pending" : "excluded")"
    )
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

  // MARK: - Bindings

  private var includeBinding: Binding<Bool> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.isIncluded ?? false },
      set: { _ in viewModel.toggleInclude(rowID: row.id) }
    )
  }

  private var valueBinding: Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.newValueText ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].newValueText = newValue
        }
      }
    )
  }

  private var assetNameBinding: Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.assetName ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].assetName = newValue
        }
      }
    )
  }

  private var currencyBinding: Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.currency ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].currency = newValue
        }
      }
    )
  }

  private var categoryNameBinding: Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.categoryName ?? "" },
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

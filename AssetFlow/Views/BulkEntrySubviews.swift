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
  let hasEmptyCashFlowDescriptions: Bool
  let hasEmptyCashFlowAmounts: Bool
  let hasCashFlowValidationErrors: Bool

  @State private var isHovering = false
  @Environment(\.isAppLocked) private var isLocked

  private var warnings: [String] {
    var result: [String] = []
    if zeroValueCount > 0 {
      result.append(
        String(
          localized:
            "\(zeroValueCount) assets have a value of 0. Exclude them or enter a non-zero value.",
          table: "Snapshot"))
    }
    if hasInvalidNewRows {
      result.append(
        String(
          localized: "Some new assets are missing a name.",
          table: "Snapshot"))
    }
    if hasDuplicateNames {
      result.append(
        String(
          localized: "Duplicate asset names found within a platform.",
          table: "Snapshot"))
    }
    if hasEmptyCashFlowDescriptions {
      result.append(
        String(
          localized: "Some cash flows are missing a description.",
          table: "Snapshot"))
    }
    if hasEmptyCashFlowAmounts {
      result.append(
        String(
          localized: "Some cash flows are missing an amount.",
          table: "Snapshot"))
    }
    if hasCashFlowValidationErrors {
      result.append(
        String(
          localized: "Some cash flows have invalid amounts.",
          table: "Snapshot"))
    }
    return result
  }

  var body: some View {
    Image(systemName: "exclamationmark.triangle.fill")
      .foregroundStyle(.red)
      .imageScale(.large)
      .opacity(warnings.isEmpty ? 0 : 1)
      .onHoverWhenUnlocked { hovering in
        isHovering = hovering
      }
      .popover(
        isPresented: Binding(
          get: { !isLocked && isHovering && !warnings.isEmpty },
          set: { if !$0 { isHovering = false } }
        ),
        arrowEdge: .bottom
      ) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(warnings, id: \.self) { warning in
            Label(warning, systemImage: "exclamationmark.triangle.fill")
              .font(.callout)
              .foregroundStyle(.red)
          }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(idealWidth: 300, alignment: .leading)
        .padding()
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

// MARK: - Cash Flow Section

/// The entire cash flow section extracted as its own observation boundary.
///
/// By placing all `viewModel.cashFlowRows` accesses (header count badge,
/// row list, etc.) inside this struct, mutations to cash flow rows only
/// invalidate this subtree — not the parent `BulkEntryView.body` which
/// also reads asset-related properties like `platformGroups`.
struct BulkEntryCashFlowSection: View {
  var viewModel: BulkEntryViewModel
  @Binding var showCSVImporter: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
        .padding(.top, 24)

      BulkEntryCashFlowList(viewModel: viewModel)
    }
    .padding(.bottom, 16)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Text("Cash Flow Operations")
        .font(.title3)
        .fontWeight(.bold)

      if !viewModel.cashFlowRows.isEmpty {
        Text("\(viewModel.cashFlowCount)")
          .font(.caption)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.quaternary, in: Capsule())
      }

      Spacer()

      Button {
        viewModel.addManualCashFlowRow()
      } label: {
        Label("Add Cash Flow", systemImage: "plus")
          .font(.callout)
      }
      .helpWhenUnlocked("Add a new cash flow operation")

      Button {
        showCSVImporter = true
      } label: {
        Label("Import CSV", systemImage: "doc.text")
          .font(.callout)
      }
      .helpWhenUnlocked("Import cash flows from a CSV file")
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
  }
}

// MARK: - Cash Flow Row List

/// Isolates the cash flow `ForEach` into its own observation boundary.
///
/// When this struct's `body` accesses `viewModel.cashFlowRows`, only this
/// subtree is invalidated on mutations — the parent `BulkEntryView.body`
/// (which also reads asset-related properties like `platformGroups` and
/// `duplicateNameRowIDs`) is NOT re-evaluated.
struct BulkEntryCashFlowList: View {
  var viewModel: BulkEntryViewModel

  var body: some View {
    if !viewModel.cashFlowRows.isEmpty {
      BulkEntryCashFlowColumnHeaders()
      ForEach(viewModel.cashFlowRows) { row in
        BulkEntryCashFlowRowView(
          viewModel: viewModel,
          row: row,
          onDelete: { viewModel.removeCashFlowRow(rowID: row.id) })
        Divider()
      }
    }
  }
}

// MARK: - Cash Flow Column Headers View

struct BulkEntryCashFlowColumnHeaders: View {
  var body: some View {
    HStack(spacing: 8) {
      Text("Include")
        .frame(width: 60, alignment: .center)
      Text("Description")
        .frame(minWidth: 150, alignment: .leading)
      Spacer()
      Text("Amount")
        .frame(width: 160, alignment: .trailing)
      Text("Currency")
        .frame(width: 80, alignment: .center)
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

// MARK: - Cash Flow Entry Row View

struct BulkEntryCashFlowRowView: View {
  var viewModel: BulkEntryViewModel
  let row: BulkEntryCashFlowRow
  let onDelete: () -> Void

  var body: some View {
    let isExcluded = !row.isIncluded

    HStack(spacing: 8) {
      // Include toggle
      Toggle("", isOn: includeBinding)
        .labelsHidden()
        .accessibilityLabel("Include \(row.cashFlowDescription)")
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this cash flow from the snapshot")

      // Description + source badge
      HStack(spacing: 6) {
        TextField("Description", text: descriptionBinding)
          .textFieldStyle(.roundedBorder)
          .frame(minWidth: 150)
          .disabled(isExcluded)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(
                row.hasEmptyDescription && row.isIncluded ? .red : .clear,
                lineWidth: 1.5))
        sourceBadge
      }
      .frame(minWidth: 150, alignment: .leading)

      Spacer()

      // Amount field
      TextField("Enter amount", text: amountBinding)
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(width: 160)
        .multilineTextAlignment(.trailing)
        .disabled(isExcluded)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              row.hasValidationError || row.hasEmptyAmount ? .red : .clear,
              lineWidth: 1.5))

      // Currency picker
      CashFlowCurrencyPicker(selection: currencyBinding)
        .frame(width: 80)
        .disabled(isExcluded)

      // Delete button (only for manualNew)
      if row.source == .manualNew {
        Button {
          onDelete()
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

  // MARK: - Bindings

  private var includeBinding: Binding<Bool> {
    Binding(
      get: { row.isIncluded },
      set: { _ in viewModel.toggleCashFlowInclude(rowID: row.id) })
  }

  private var descriptionBinding: Binding<String> {
    Binding(
      get: { row.cashFlowDescription },
      set: { newValue in
        if let index = viewModel.cashFlowRows.firstIndex(where: { $0.id == row.id }) {
          viewModel.cashFlowRows[index].cashFlowDescription = newValue
        }
      })
  }

  private var amountBinding: Binding<String> {
    Binding(
      get: { row.amountText },
      set: { newValue in
        if let index = viewModel.cashFlowRows.firstIndex(where: { $0.id == row.id }) {
          viewModel.cashFlowRows[index].amountText = newValue
        }
      })
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

// MARK: - Cash Flow Currency Picker

/// An extracted currency picker that avoids rebuilding 340+ items on every parent re-render.
///
/// By isolating the `ForEach(CurrencyService.shared.currencies)` in its own `View` struct,
/// SwiftUI can skip re-diffing the picker content when only the parent's other state changes
/// (e.g., typing in a description field). The `@Binding` only triggers re-render when the
/// selected currency actually changes.
struct CashFlowCurrencyPicker: View {
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

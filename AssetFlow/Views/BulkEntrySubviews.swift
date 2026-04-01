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

// MARK: - Toolbar

/// Toolbar extracted as its own observation boundary.
///
/// Reading `viewModel.updatedCount`, `pendingCount`, `excludedCount`, etc.
/// inside this struct means that `rows` mutations only invalidate this
/// subtree — not the parent `BulkEntryView.body`.
struct BulkEntryToolbar: View {
  var viewModel: BulkEntryViewModel
  let onSave: () -> Void

  @State private var showAddPlatformPopover = false
  @State private var newPlatformName = ""
  @State private var addPlatformError = ""

  var body: some View {
    HStack(spacing: 16) {
      Text("New Snapshot — \(viewModel.snapshotDate.settingsFormatted())")
        .font(.headline)

      Spacer()

      BulkEntryProgressStats(
        updatedCount: viewModel.updatedCount,
        pendingCount: viewModel.pendingCount,
        excludedCount: viewModel.excludedCount
      )

      BulkEntryValidationWarnings(
        zeroValueCount: viewModel.zeroValueCount,
        hasInvalidNewRows: viewModel.hasInvalidNewRows,
        hasEmptyCashFlowDescriptions: viewModel.hasEmptyCashFlowDescriptions,
        hasEmptyCashFlowAmounts: viewModel.hasEmptyCashFlowAmounts,
        hasCashFlowValidationErrors: viewModel.hasCashFlowValidationErrors
      )

      Button {
        newPlatformName = ""
        addPlatformError = ""
        showAddPlatformPopover = true
      } label: {
        Label("Add Platform", systemImage: "plus.rectangle.on.folder")
      }
      .helpWhenUnlocked("Add a new platform with an empty asset")
      .popover(isPresented: $showAddPlatformPopover, arrowEdge: .bottom) {
        addPlatformPopover
      }

      Button("Save Snapshot") {
        onSave()
      }
      .buttonStyle(.borderedProminent)
      .disabled(!viewModel.canSave)
      .helpWhenUnlocked("Save the snapshot with entered values")
      .accessibilityIdentifier("Save Snapshot Button")
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial)
  }

  private var addPlatformPopover: some View {
    VStack(spacing: 12) {
      Text("New Platform")
        .font(.headline)
      TextField("Platform name", text: $newPlatformName)
        .textFieldStyle(.roundedBorder)
        .onSubmit { commitNewPlatform() }
      if !addPlatformError.isEmpty {
        Text(addPlatformError)
          .font(.caption)
          .foregroundStyle(.red)
      }
      HStack {
        Button("Cancel") { showAddPlatformPopover = false }
        Button("Add") { commitNewPlatform() }
          .buttonStyle(.borderedProminent)
          .disabled(newPlatformName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding()
    .frame(width: 260)
  }

  private func commitNewPlatform() {
    let trimmed = newPlatformName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      addPlatformError = String(
        localized: "Platform name cannot be empty.", table: "Snapshot")
      return
    }
    if let rowID = viewModel.addPlatform(name: trimmed) {
      showAddPlatformPopover = false
      viewModel.pendingFocusRowID = rowID
    } else {
      addPlatformError = String(
        localized: "A platform with this name already exists.", table: "Snapshot")
    }
  }
}

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

// MARK: - Content Area

/// Owns the `viewModel.rows.isEmpty` observation so that `BulkEntryView.body`
/// does not depend on `rows`, preventing cascading re-evaluations of unrelated
/// children (toolbar, cash flow section) on every asset row commit.
struct BulkEntryContentArea: View {
  var viewModel: BulkEntryViewModel
  @Binding var cachedCategoryNames: [String]
  var csvImportPlatform: Binding<String>
  var showCSVImporter: Binding<Bool>
  @Binding var showCashFlowCSVImporter: Bool

  @State private var showEmptyStatePopover = false
  @State private var emptyStatePlatformName = ""
  @State private var emptyStatePlatformError = ""

  var body: some View {
    if viewModel.rows.isEmpty {
      ContentUnavailableView {
        Label("No Assets", systemImage: "tray")
      } description: {
        Text(
          "Add a platform to start building your snapshot, or import assets from a CSV file."
        )
      } actions: {
        Button("Add Platform") {
          emptyStatePlatformName = ""
          emptyStatePlatformError = ""
          showEmptyStatePopover = true
        }
        .buttonStyle(.borderedProminent)
        .popover(isPresented: $showEmptyStatePopover, arrowEdge: .bottom) {
          emptyStateAddPlatformPopover
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
          BulkEntryAssetSection(
            viewModel: viewModel,
            cachedCategoryNames: $cachedCategoryNames,
            csvImportPlatform: csvImportPlatform,
            showCSVImporter: showCSVImporter)
          BulkEntryCashFlowSection(
            viewModel: viewModel,
            showCSVImporter: $showCashFlowCSVImporter)
        }
        .padding()
      }
    }
  }

  private var emptyStateAddPlatformPopover: some View {
    VStack(spacing: 12) {
      Text("New Platform")
        .font(.headline)
      TextField("Platform name", text: $emptyStatePlatformName)
        .textFieldStyle(.roundedBorder)
        .onSubmit { commitEmptyStatePlatform() }
      if !emptyStatePlatformError.isEmpty {
        Text(emptyStatePlatformError)
          .font(.caption)
          .foregroundStyle(.red)
      }
      HStack {
        Button("Cancel") { showEmptyStatePopover = false }
        Button("Add") { commitEmptyStatePlatform() }
          .buttonStyle(.borderedProminent)
          .disabled(emptyStatePlatformName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding()
    .frame(width: 260)
  }

  private func commitEmptyStatePlatform() {
    let trimmed = emptyStatePlatformName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      emptyStatePlatformError = String(
        localized: "Platform name cannot be empty.", table: "Snapshot")
      return
    }
    if let rowID = viewModel.addPlatform(name: trimmed) {
      showEmptyStatePopover = false
      viewModel.pendingFocusRowID = rowID
    } else {
      emptyStatePlatformError = String(
        localized: "A platform with this name already exists.", table: "Snapshot")
    }
  }
}

// MARK: - Asset Section

/// The entire asset section extracted as its own observation boundary.
///
/// By placing `viewModel.platformGroups` access inside this struct, mutations
/// to `rows` only invalidate this subtree — not the parent `BulkEntryView.body`.
/// This mirrors the `BulkEntryCashFlowSection` pattern for cash flow rows.
struct BulkEntryAssetSection: View {
  var viewModel: BulkEntryViewModel
  @Binding var cachedCategoryNames: [String]
  var csvImportPlatform: Binding<String>
  var showCSVImporter: Binding<Bool>
  @FocusState private var focusedRowID: UUID?
  @FocusState private var nameFieldFocusedRowID: UUID?

  var body: some View {
    ForEach(viewModel.platformGroups, id: \.platform) { group in
      BulkEntryPlatformSection(
        viewModel: viewModel,
        platform: group.platform,
        rows: group.rows,
        cachedCategoryNames: $cachedCategoryNames,
        focusedRowID: $focusedRowID,
        nameFieldFocusedRowID: $nameFieldFocusedRowID,
        csvImportPlatform: csvImportPlatform,
        showCSVImporter: showCSVImporter
      )
      .equatable()
    }
    .onChange(of: viewModel.pendingFocusRowID) { _, rowID in
      guard let rowID else { return }
      let isNewRow = viewModel.rows.first(where: { $0.id == rowID })?.isNewRow ?? false
      if isNewRow {
        nameFieldFocusedRowID = rowID
      } else {
        focusedRowID = rowID
      }
      viewModel.pendingFocusRowID = nil
    }
  }
}

/// A single platform's header + rows, extracted as an Equatable observation boundary.
///
/// When only one platform's rows change, SwiftUI compares `platform` and `rows`
/// via `Equatable` and skips body re-evaluation for all unchanged platforms.
struct BulkEntryPlatformSection: View, Equatable {
  var viewModel: BulkEntryViewModel
  let platform: String
  let rows: [BulkEntryRow]
  @Binding var cachedCategoryNames: [String]
  var focusedRowID: FocusState<UUID?>.Binding
  var nameFieldFocusedRowID: FocusState<UUID?>.Binding
  var csvImportPlatform: Binding<String>
  var showCSVImporter: Binding<Bool>

  static func == (lhs: BulkEntryPlatformSection, rhs: BulkEntryPlatformSection) -> Bool {
    lhs.platform == rhs.platform && lhs.rows == rhs.rows
      && lhs.cachedCategoryNames == rhs.cachedCategoryNames
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      platformHeader
      BulkEntryColumnHeaders()
      ForEach(rows) { row in
        BulkEntryRowView(
          viewModel: viewModel,
          row: row,
          cachedCategoryNames: $cachedCategoryNames,
          focusedRowID: focusedRowID,
          nameFieldFocusedRowID: nameFieldFocusedRowID
        )
        .equatable()
        Divider()
      }
    }
    .padding(.bottom, 16)
  }

  private var platformHeader: some View {
    HStack(spacing: 12) {
      Text(platform.isEmpty ? "No Platform" : platform)
        .font(.title3)
        .fontWeight(.bold)

      Text("\(rows.count)")
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())

      let groupUpdated = rows.filter(\.isUpdated).count
      let groupTotal = rows.filter(\.isIncluded).count
      Text("\(groupUpdated)/\(groupTotal)")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        let rowID = viewModel.addManualRow(forPlatform: platform)
        nameFieldFocusedRowID.wrappedValue = rowID
      } label: {
        Label("Add Asset", systemImage: "plus")
          .font(.callout)
      }
      .helpWhenUnlocked("Add a new asset to this platform")

      Button {
        csvImportPlatform.wrappedValue = platform
        showCSVImporter.wrappedValue = true
      } label: {
        Label("Import CSV", systemImage: "doc.text")
          .font(.callout)
      }
      .helpWhenUnlocked("Import a CSV file to fill values for this platform")
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
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
/// is NOT re-evaluated.
struct BulkEntryCashFlowList: View {
  var viewModel: BulkEntryViewModel

  var body: some View {
    if !viewModel.cashFlowRows.isEmpty {
      BulkEntryCashFlowColumnHeaders()
      ForEach(viewModel.cashFlowRows) { row in
        BulkEntryCashFlowRowView(
          viewModel: viewModel,
          row: row
        )
        .equatable()
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

struct BulkEntryCashFlowRowView: View, Equatable {
  var viewModel: BulkEntryViewModel
  let row: BulkEntryCashFlowRow

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
          .focused($focusedField, equals: .description)
          .onSubmit { commitDescription() }
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
        .focused($focusedField, equals: .amount)
        .onSubmit { commitAmount() }
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
    .onAppear {
      localDescription = row.cashFlowDescription
      localAmount = row.amountText
    }
    .onChange(of: row.cashFlowDescription) { _, newValue in
      localDescription = newValue
    }
    .onChange(of: row.amountText) { _, newValue in
      localAmount = newValue
    }
    .onChange(of: focusedField) { oldValue, _ in
      if oldValue == .description { commitDescription() }
      if oldValue == .amount { commitAmount() }
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

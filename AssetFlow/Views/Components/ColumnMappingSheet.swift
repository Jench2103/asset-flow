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

/// Sheet for mapping arbitrary CSV column headers to canonical AssetFlow columns.
///
/// Presents a full CSV table preview with a dropdown above each column,
/// allowing users to assign each CSV column to a canonical field or skip it.
/// Auto-detected mappings are pre-selected.
struct ColumnMappingSheet: View {
  let rawHeaders: [String]
  let schema: CSVColumnSchema
  let sampleRows: [[String]]
  let initialMapping: [CanonicalColumn: Int]
  let parentSize: CGSize?
  let onConfirm: (CSVColumnMapping) -> Void
  let onCancel: () -> Void

  @State private var columnAssignments: [CanonicalColumn?]
  @State private var measuredTableSize: CGSize = .zero
  @State private var measuredChromeSize: CGSize = .zero

  init(
    rawHeaders: [String],
    schema: CSVColumnSchema,
    sampleRows: [[String]],
    initialMapping: [CanonicalColumn: Int],
    parentSize: CGSize? = nil,
    onConfirm: @escaping (CSVColumnMapping) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.rawHeaders = rawHeaders
    self.schema = schema
    self.sampleRows = sampleRows
    self.initialMapping = initialMapping
    self.parentSize = parentSize
    self.onConfirm = onConfirm
    self.onCancel = onCancel

    // Build initial assignments array from the partial mapping (inverse: index → column)
    var assignments = [CanonicalColumn?](repeating: nil, count: rawHeaders.count)
    for (column, index) in initialMapping where index < rawHeaders.count {
      assignments[index] = column
    }
    _columnAssignments = State(initialValue: assignments)
  }

  // MARK: - Computed

  private var mappedRequiredCount: Int {
    let mapped = Set(columnAssignments.compactMap { $0 })
    return schema.requiredColumns.filter { mapped.contains($0) }.count
  }

  private var allRequiredMapped: Bool {
    mappedRequiredCount == schema.requiredColumns.count
  }

  private var hasDuplicateAssignments: Bool {
    let assigned = columnAssignments.compactMap { $0 }
    return assigned.count != Set(assigned).count
  }

  private var duplicateColumns: Set<CanonicalColumn> {
    let assigned = columnAssignments.compactMap { $0 }
    var seen = Set<CanonicalColumn>()
    var duplicates = Set<CanonicalColumn>()
    for col in assigned where !seen.insert(col).inserted {
      duplicates.insert(col)
    }
    return duplicates
  }

  private var isConfirmDisabled: Bool {
    !allRequiredMapped || hasDuplicateAssignments
  }

  private var maxSheetWidth: CGFloat {
    guard let parentSize, parentSize.width > 0 else { return Self.defaultSheetWidth }
    return parentSize.width * Self.maxParentRatio
  }

  private var maxSheetHeight: CGFloat {
    guard let parentSize, parentSize.height > 0 else { return Self.defaultSheetHeight }
    return parentSize.height * Self.maxParentRatio
  }

  private var maxTableViewportWidth: CGFloat {
    max(1, maxSheetWidth - Self.contentHorizontalPadding)
  }

  private var maxTableViewportHeight: CGFloat {
    max(1, maxSheetHeight - measuredChromeSize.height)
  }

  private var needsHorizontalScroll: Bool {
    measuredTableSize.width > maxTableViewportWidth
  }

  private var needsVerticalScroll: Bool {
    measuredTableSize.height + horizontalScrollbarHeight > maxTableViewportHeight
  }

  private var horizontalScrollbarHeight: CGFloat {
    needsHorizontalScroll ? Self.scrollbarClearance : 0
  }

  private var tableViewportWidth: CGFloat? {
    guard measuredTableSize.width > 0 else { return nil }
    return min(measuredTableSize.width, maxTableViewportWidth)
  }

  private var tableViewportHeight: CGFloat? {
    guard measuredTableSize.height > 0, measuredChromeSize.height > 0 else { return nil }
    return min(measuredTableSize.height + horizontalScrollbarHeight, maxTableViewportHeight)
  }

  private var sheetWidth: CGFloat? {
    guard let tableViewportWidth else { return nil }
    return min(
      max(measuredChromeSize.width, tableViewportWidth + Self.contentHorizontalPadding),
      maxSheetWidth)
  }

  private var sheetHeight: CGFloat? {
    guard let tableViewportHeight, measuredChromeSize.height > 0 else { return nil }
    return min(measuredChromeSize.height + tableViewportHeight, maxSheetHeight)
  }

  // MARK: - Body

  var body: some View {
    sheetContent(table: csvTable)
      .frame(
        width: sheetWidth,
        height: sheetHeight,
        alignment: .topLeading
      )
      .frame(
        maxWidth: maxSheetWidth,
        maxHeight: maxSheetHeight,
        alignment: .topLeading
      )
      .background(chromeMeasurement)
      .background(tableMeasurement)
      .onPreferenceChange(ChromeSizePreferenceKey.self) { size in
        measuredChromeSize = size
      }
      .onPreferenceChange(CSVTableSizePreferenceKey.self) { size in
        measuredTableSize = size
      }
  }

  private func sheetContent(table: some View) -> some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Text(String(localized: "Map CSV Columns", table: "Import"))
          .font(.headline)

        Divider()

        Text(
          String(
            localized:
              "Use the dropdowns above each column to assign it to the corresponding field.",
            table: "Import")
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        table
        statusBar
      }
      .padding()

      Divider()

      HStack {
        Spacer()
        Button(String(localized: "Cancel", table: "Import")) {
          onCancel()
        }
        Button(String(localized: "Confirm", table: "Import")) {
          confirmMapping()
        }
        .buttonStyle(.borderedProminent)
        .disabled(isConfirmDisabled)
      }
      .padding()
    }
  }

  private var chromeMeasurement: some View {
    sheetContent(table: Color.clear.frame(width: 0, height: 0))
      .fixedSize()
      .hidden()
      .accessibilityHidden(true)
      .allowsHitTesting(false)
      .readSize(key: ChromeSizePreferenceKey.self)
  }

  // MARK: - CSV Table

  @ViewBuilder
  private var csvTable: some View {
    if needsHorizontalScroll || needsVerticalScroll {
      ScrollView(scrollAxes) {
        csvGrid
          .fixedSize()
      }
      .frame(
        width: tableViewportWidth,
        height: tableViewportHeight,
        alignment: .topLeading
      )
      .layoutPriority(1)
    } else {
      csvGrid
        .fixedSize()
        .frame(
          width: tableViewportWidth,
          height: tableViewportHeight,
          alignment: .topLeading
        )
        .layoutPriority(1)
    }
  }

  private var scrollAxes: Axis.Set {
    switch (needsHorizontalScroll, needsVerticalScroll) {
    case (true, true):
      return [.horizontal, .vertical]

    case (true, false):
      return .horizontal

    case (false, true):
      return .vertical

    case (false, false):
      return []
    }
  }

  private var tableMeasurement: some View {
    csvGrid
      .fixedSize()
      .hidden()
      .accessibilityHidden(true)
      .allowsHitTesting(false)
      .readSize(key: CSVTableSizePreferenceKey.self)
  }

  private var csvGrid: some View {
    Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
      // Row 0: Pickers — compute duplicateColumns once per render, not per cell
      let dupes = duplicateColumns
      GridRow {
        ForEach(Array(rawHeaders.enumerated()), id: \.offset) { index, _ in
          pickerCell(at: index, duplicates: dupes)
        }
      }

      Divider()
        .gridCellColumns(rawHeaders.count)

      // Row 1: CSV headers
      GridRow {
        ForEach(Array(rawHeaders.enumerated()), id: \.offset) { _, header in
          Text(header)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(minWidth: 100, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
      }

      Divider()
        .gridCellColumns(rawHeaders.count)

      // Data rows
      ForEach(Array(sampleRows.enumerated()), id: \.offset) { _, row in
        GridRow {
          ForEach(Array(row.enumerated()), id: \.offset) { _, value in
            Text(value)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .frame(minWidth: 100, alignment: .leading)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
          }
          // Pad if row has fewer fields than headers
          if row.count < rawHeaders.count {
            ForEach(row.count..<rawHeaders.count, id: \.self) { _ in
              Text("")
                .frame(minWidth: 100, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
          }
        }
      }
    }
  }

  // MARK: - Picker Cell

  private func pickerCell(at index: Int, duplicates: Set<CanonicalColumn>) -> some View {
    let isDuplicate =
      columnAssignments[index].map { duplicates.contains($0) } ?? false

    return Picker(
      "",
      selection: $columnAssignments[index]
    ) {
      Text(String(localized: "— Skip —", table: "Import"))
        .tag(CanonicalColumn?.none)

      ForEach(schema.allColumns) { column in
        Text(column.rawValue)
          .tag(CanonicalColumn?.some(column))
      }
    }
    .labelsHidden()
    .frame(minWidth: 100)
    .padding(.horizontal, 4)
    .padding(.vertical, 4)
    .overlay(
      isDuplicate
        ? RoundedRectangle(cornerRadius: 4).stroke(.red, lineWidth: 1.5)
        : nil
    )
  }

  // MARK: - Status Bar

  private var statusBar: some View {
    VStack(alignment: .leading, spacing: 4) {
      if hasDuplicateAssignments {
        Label {
          Text(
            String(
              localized: "Two or more columns are mapped to the same field.",
              table: "Import")
          )
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
        }
        .font(.callout)
      }

      Label {
        Text(
          String(
            localized:
              "\(mappedRequiredCount) of \(schema.requiredColumns.count) required columns mapped.",
            table: "Import")
        )
      } icon: {
        Image(
          systemName: allRequiredMapped
            ? "checkmark.circle.fill"
            : "info.circle.fill"
        )
        .foregroundStyle(allRequiredMapped ? .green : .secondary)
      }
      .font(.callout)
    }
  }

  // MARK: - Actions

  private func confirmMapping() {
    var columnMap: [CanonicalColumn: Int] = [:]
    for (index, assignment) in columnAssignments.enumerated() {
      if let column = assignment {
        columnMap[column] = index
      }
    }
    let mapping = CSVColumnMapping(
      schema: schema, columnMap: columnMap, rawHeaders: rawHeaders)
    onConfirm(mapping)
  }
}

extension ColumnMappingSheet {
  private static let maxParentRatio: CGFloat = 0.8
  private static let defaultSheetWidth: CGFloat = 640
  private static let defaultSheetHeight: CGFloat = 520
  private static let contentHorizontalPadding: CGFloat = 32
  private static let scrollbarClearance: CGFloat = 24
}

private struct CSVTableSizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    let next = nextValue()
    value = CGSize(
      width: max(value.width, next.width),
      height: max(value.height, next.height))
  }
}

private struct ChromeSizePreferenceKey: PreferenceKey {
  static let defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    let next = nextValue()
    value = CGSize(
      width: max(value.width, next.width),
      height: max(value.height, next.height))
  }
}

extension View {
  fileprivate func readSize<Key: PreferenceKey>(key: Key.Type) -> some View
  where Key.Value == CGSize {
    background(
      GeometryReader { proxy in
        Color.clear.preference(key: key, value: proxy.size)
      }
    )
  }
}

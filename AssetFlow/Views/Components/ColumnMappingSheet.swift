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
  let onConfirm: (CSVColumnMapping) -> Void
  let onCancel: () -> Void

  @State private var columnAssignments: [CanonicalColumn?]

  init(
    rawHeaders: [String],
    schema: CSVColumnSchema,
    sampleRows: [[String]],
    initialMapping: [CanonicalColumn: Int],
    onConfirm: @escaping (CSVColumnMapping) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.rawHeaders = rawHeaders
    self.schema = schema
    self.sampleRows = sampleRows
    self.initialMapping = initialMapping
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

  // MARK: - Body

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          String(
            localized:
              "Use the dropdowns above each column to assign it to the corresponding field.",
            table: "Import")
        )
        .font(.callout)
        .foregroundStyle(.secondary)

        csvTable

        statusBar
      }
      .padding()
      .frame(minWidth: 560, idealWidth: 640)
      .navigationTitle(
        String(localized: "Map CSV Columns", table: "Import")
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "Cancel", table: "Import")) {
            onCancel()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "Confirm", table: "Import")) {
            confirmMapping()
          }
          .buttonStyle(.borderedProminent)
          .disabled(isConfirmDisabled)
        }
      }
    }
  }

  // MARK: - CSV Table

  private var csvTable: some View {
    ScrollView(.horizontal) {
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
      .padding(.bottom, 8)
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

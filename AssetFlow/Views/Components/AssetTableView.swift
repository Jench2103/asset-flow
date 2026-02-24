//
//  AssetTableView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/24.
//

import SwiftUI

/// Shared row data for asset tables in platform and category detail views.
struct DetailAssetRowData: Identifiable {
  var id: UUID { asset.id }
  let asset: Asset
  let latestValue: Decimal?
  let convertedValue: Decimal?
}

/// Reusable asset table with a configurable second column and conditional "Converted Value" column.
///
/// The "Converted Value" column is automatically hidden when no rows have converted values
/// (i.e., all assets use the same currency as the main display currency).
struct AssetTableView<SecondColumn: View>: View {
  let rows: [DetailAssetRowData]
  let secondColumnTitle: LocalizedStringKey
  let secondColumnContent: (DetailAssetRowData) -> SecondColumn

  init(
    rows: [DetailAssetRowData],
    secondColumnTitle: LocalizedStringKey,
    @ViewBuilder secondColumnContent: @escaping (DetailAssetRowData) -> SecondColumn
  ) {
    self.rows = rows
    self.secondColumnTitle = secondColumnTitle
    self.secondColumnContent = secondColumnContent
  }

  private var hasConvertedValues: Bool {
    rows.contains { $0.convertedValue != nil }
  }

  var body: some View {
    if hasConvertedValues {
      tableWithConvertedValue
    } else {
      tableWithoutConvertedValue
    }
  }

  private var tableWithConvertedValue: some View {
    Table(rows) {
      TableColumn("Name") { (row: DetailAssetRowData) in
        Text(row.asset.name)
      }
      TableColumn(secondColumnTitle) { (row: DetailAssetRowData) in
        secondColumnContent(row)
      }
      TableColumn("Original Value") { (row: DetailAssetRowData) in
        originalValueCell(row)
      }
      .alignment(.trailing)
      TableColumn("Converted Value") { (row: DetailAssetRowData) in
        convertedValueCell(row)
      }
      .alignment(.trailing)
    }
    .modifier(AssetTableModifier(rowCount: rows.count))
  }

  private var tableWithoutConvertedValue: some View {
    Table(rows) {
      TableColumn("Name") { (row: DetailAssetRowData) in
        Text(row.asset.name)
      }
      TableColumn(secondColumnTitle) { (row: DetailAssetRowData) in
        secondColumnContent(row)
      }
      TableColumn("Original Value") { (row: DetailAssetRowData) in
        originalValueCell(row)
      }
      .alignment(.trailing)
    }
    .modifier(AssetTableModifier(rowCount: rows.count))
  }

  @ViewBuilder
  private func originalValueCell(_ row: DetailAssetRowData) -> some View {
    if let value = row.latestValue {
      let effectiveCurrency =
        row.asset.currency.isEmpty
        ? SettingsService.shared.mainCurrency : row.asset.currency
      HStack(spacing: 4) {
        if effectiveCurrency != SettingsService.shared.mainCurrency {
          Text(effectiveCurrency.uppercased())
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
        }
        Text(value.formatted(currency: effectiveCurrency))
          .monospacedDigit()
      }
    } else {
      Text("\u{2014}")
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func convertedValueCell(_ row: DetailAssetRowData) -> some View {
    if let converted = row.convertedValue {
      Text(converted.formatted(currency: SettingsService.shared.mainCurrency))
        .monospacedDigit()
    } else {
      Text("\u{2014}")
        .foregroundStyle(.secondary)
    }
  }
}

/// Shared table style modifiers for asset tables.
private struct AssetTableModifier: ViewModifier {
  let rowCount: Int

  func body(content: Content) -> some View {
    content
      .tableStyle(.bordered(alternatesRowBackgrounds: true))
      .scrollDisabled(true)
      .frame(height: CGFloat(rowCount) * 24 + 32)
      .padding(-1)
      .clipped()
  }
}

//
//  ImportView+Previews.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Hover Popover Icon

private struct HoverPopoverIcon: View {
  let systemName: String
  let color: Color
  let message: String
  @Binding var activeRowID: UUID?
  let rowID: UUID
  @Environment(\.isAppLocked) private var isLocked

  var body: some View {
    Image(systemName: systemName)
      .font(.caption2)
      .foregroundStyle(color)
      .onHover { hovering in
        if isLocked {
          activeRowID = nil
        } else {
          activeRowID = hovering ? rowID : nil
        }
      }
      .popover(
        isPresented: Binding(
          get: { !isLocked && activeRowID == rowID },
          set: { if !$0 { activeRowID = nil } }
        ),
        arrowEdge: .bottom
      ) {
        Text(message)
          .font(.callout)
          .fixedSize(horizontal: false, vertical: true)
          .frame(idealWidth: 300, alignment: .leading)
          .padding()
      }
  }
}

// MARK: - Preview Tables and File Handling

extension ImportView {

  var assetPreviewTable: some View {
    VStack(spacing: 0) {
      // Header row — CSV column names are intentionally non-localizable
      HStack {
        Text(verbatim: "Asset Name")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(verbatim: "Market Value")
          .fontWeight(.semibold)
          .frame(width: 120, alignment: .trailing)
        Text(verbatim: "Currency")
          .fontWeight(.semibold)
          .frame(width: 80, alignment: .leading)
        Text(verbatim: "Platform")
          .fontWeight(.semibold)
          .frame(width: 150, alignment: .leading)
        Text(verbatim: "Category")
          .fontWeight(.semibold)
          .frame(width: 120, alignment: .leading)
        Text("")
          .frame(width: 30)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(.fill.quaternary)

      Divider()

      // Data rows
      ForEach(
        Array(viewModel.assetPreviewRows.enumerated()), id: \.element.id
      ) { index, row in
        if row.isIncluded {
          HStack {
            HStack(spacing: 4) {
              Text(row.csvRow.assetName)
              if let error = row.duplicateError {
                HoverPopoverIcon(
                  systemName: "xmark.circle.fill",
                  color: .red,
                  message: error,
                  activeRowID: $activeDuplicateErrorRowID,
                  rowID: row.id
                )
              }
              if let error = row.snapshotDuplicateError {
                HoverPopoverIcon(
                  systemName: "xmark.circle.fill",
                  color: .red,
                  message: error,
                  activeRowID: $activeSnapshotDuplicateErrorRowID,
                  rowID: row.id
                )
              }
              if let warning = row.categoryWarning {
                HoverPopoverIcon(
                  systemName: "exclamationmark.triangle.fill",
                  color: .yellow,
                  message: warning,
                  activeRowID: $activeCategoryWarningRowID,
                  rowID: row.id
                )
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
              Text(row.csvRow.marketValue.formatted())
                .monospacedDigit()
              if let warning = row.marketValueWarning {
                HoverPopoverIcon(
                  systemName: "exclamationmark.triangle.fill",
                  color: .yellow,
                  message: warning,
                  activeRowID: $activeMarketValueWarningRowID,
                  rowID: row.id
                )
              }
            }
            .frame(width: 120, alignment: .trailing)

            HStack(spacing: 4) {
              Text(row.effectiveCurrency.isEmpty ? "-" : row.effectiveCurrency)
                .foregroundStyle(row.effectiveCurrency.isEmpty ? .tertiary : .primary)
              if let error = row.currencyError {
                HoverPopoverIcon(
                  systemName: "xmark.circle.fill",
                  color: .red,
                  message: error,
                  activeRowID: $activeCurrencyErrorRowID,
                  rowID: row.id
                )
              } else if let warning = row.currencyWarning {
                HoverPopoverIcon(
                  systemName: "exclamationmark.triangle.fill",
                  color: .yellow,
                  message: warning,
                  activeRowID: $activeCurrencyWarningRowID,
                  rowID: row.id
                )
              }
            }
            .frame(width: 80, alignment: .leading)

            Text(row.csvRow.platform.isEmpty ? "-" : row.csvRow.platform)
              .frame(width: 150, alignment: .leading)
              .foregroundStyle(row.csvRow.platform.isEmpty ? .tertiary : .primary)

            Text(row.effectiveCategory.isEmpty ? "-" : row.effectiveCategory)
              .frame(width: 120, alignment: .leading)
              .foregroundStyle(row.effectiveCategory.isEmpty ? .tertiary : .primary)

            Button {
              viewModel.removeAssetPreviewRow(at: index)
            } label: {
              Image(systemName: "minus.circle")
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)

          Divider()
        }
      }
    }
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(.separator, lineWidth: 1)
    )
  }

  var cashFlowPreviewTable: some View {
    VStack(spacing: 0) {
      // Header row — CSV column names are intentionally non-localizable
      HStack {
        Text(verbatim: "Description")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text(verbatim: "Amount")
          .fontWeight(.semibold)
          .frame(width: 120, alignment: .trailing)
        Text("")
          .frame(width: 30)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(.fill.quaternary)

      Divider()

      // Data rows
      ForEach(
        Array(viewModel.cashFlowPreviewRows.enumerated()), id: \.element.id
      ) { index, row in
        if row.isIncluded {
          HStack {
            HStack(spacing: 4) {
              Text(row.csvRow.description)
              if let error = row.duplicateError {
                HoverPopoverIcon(
                  systemName: "xmark.circle.fill",
                  color: .red,
                  message: error,
                  activeRowID: $activeCFDuplicateErrorRowID,
                  rowID: row.id
                )
              }
              if let error = row.snapshotDuplicateError {
                HoverPopoverIcon(
                  systemName: "xmark.circle.fill",
                  color: .red,
                  message: error,
                  activeRowID: $activeCFSnapshotDuplicateErrorRowID,
                  rowID: row.id
                )
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
              Text(row.csvRow.amount.formatted())
                .monospacedDigit()
                .foregroundStyle(row.csvRow.amount < 0 ? .red : .primary)
              if let warning = row.amountWarning {
                HoverPopoverIcon(
                  systemName: "exclamationmark.triangle.fill",
                  color: .yellow,
                  message: warning,
                  activeRowID: $activeCFAmountWarningRowID,
                  rowID: row.id
                )
              }
            }
            .frame(width: 120, alignment: .trailing)

            Button {
              viewModel.removeCashFlowPreviewRow(at: index)
            } label: {
              Image(systemName: "minus.circle")
                .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)

          Divider()
        }
      }
    }
    .background(.background)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(.separator, lineWidth: 1)
    )
  }

  func handleFileImport(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }
      let accessing = url.startAccessingSecurityScopedResource()
      defer {
        if accessing { url.stopAccessingSecurityScopedResource() }
      }
      viewModel.loadFile(url)

    case .failure:
      viewModel.validationErrors = [
        CSVError(
          row: 0, column: nil,
          message: String(
            localized: "Could not open file. Please check the file is a valid CSV.",
            table: "Import"))
      ]
    }
  }

  func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }

    if provider.hasItemConformingToTypeIdentifier(UTType.commaSeparatedText.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.commaSeparatedText.identifier) { item, _ in
        if let url = item as? URL {
          Task { @MainActor in
            viewModel.loadFile(url)
          }
        }
      }
      return true
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
        if let data = item as? Data,
          let url = URL(dataRepresentation: data, relativeTo: nil)
        {
          Task { @MainActor in
            viewModel.loadFile(url)
          }
        }
      }
      return true
    }

    return false
  }
}

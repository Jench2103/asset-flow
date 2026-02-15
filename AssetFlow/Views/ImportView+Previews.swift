//
//  ImportView+Previews.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preview Tables and File Handling

extension ImportView {

  var assetPreviewTable: some View {
    VStack(spacing: 0) {
      // Header row
      HStack {
        Text("Asset Name")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Market Value")
          .fontWeight(.semibold)
          .frame(width: 120, alignment: .trailing)
        Text("Platform")
          .fontWeight(.semibold)
          .frame(width: 150, alignment: .leading)
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
            VStack(alignment: .leading, spacing: 2) {
              Text(row.csvRow.assetName)
              if let warning = row.categoryWarning {
                HStack(spacing: 4) {
                  Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                  Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.csvRow.marketValue.formatted())
              .frame(width: 120, alignment: .trailing)
              .monospacedDigit()

            Text(row.csvRow.platform.isEmpty ? "-" : row.csvRow.platform)
              .frame(width: 150, alignment: .leading)
              .foregroundStyle(row.csvRow.platform.isEmpty ? .tertiary : .primary)

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
      // Header row
      HStack {
        Text("Description")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Amount")
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
            Text(row.csvRow.description)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.csvRow.amount.formatted())
              .frame(width: 120, alignment: .trailing)
              .monospacedDigit()
              .foregroundStyle(row.csvRow.amount < 0 ? .red : .primary)

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

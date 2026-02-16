//
//  RebalancingView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Rebalancing view showing category allocation adjustments.
///
/// Displays a table of rebalancing suggestions sorted by absolute adjustment
/// magnitude, with sections for categories without targets and uncategorized assets.
struct RebalancingView: View {
  @State private var viewModel: RebalancingViewModel

  init(modelContext: ModelContext) {
    _viewModel = State(wrappedValue: RebalancingViewModel(modelContext: modelContext))
  }

  var body: some View {
    Group {
      if viewModel.isEmpty {
        emptyState
      } else {
        rebalancingContent
      }
    }
    .navigationTitle("Rebalancing")
    .onAppear {
      viewModel.loadRebalancing()
    }
    .accessibilityIdentifier("Rebalancing View")
  }

  // MARK: - Main Content

  private var rebalancingContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        portfolioValueHeader

        if !viewModel.suggestions.isEmpty {
          suggestionsSection
        }

        if !viewModel.noTargetRows.isEmpty {
          noTargetSection
        }

        if viewModel.uncategorizedRow != nil {
          uncategorizedSection
        }

        if !viewModel.summaryTexts.isEmpty {
          summarySection
        }
      }
      .padding()
    }
  }

  // MARK: - Portfolio Value Header

  private var portfolioValueHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Total Portfolio Value")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(
        viewModel.totalPortfolioValue.formatted(
          currency: SettingsService.shared.mainCurrency)
      )
      .font(.title2.bold())
      .monospacedDigit()
    }
  }

  // MARK: - Suggestions Table

  private var suggestionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Categories with Targets")
        .font(.headline)

      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
        // Header row
        GridRow {
          Text("Category").font(.caption).foregroundStyle(.secondary)
          Text("Current Value").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text("Current %").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text("Target %").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text("Difference").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text("Action").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
        }

        Divider()
          .gridCellUnsizedAxes(.horizontal)

        ForEach(viewModel.suggestions) { suggestion in
          suggestionRow(suggestion)
        }
      }
    }
  }

  private func suggestionRow(_ suggestion: RebalancingRowData) -> some View {
    let currency = SettingsService.shared.mainCurrency

    return GridRow {
      Text(suggestion.categoryName)
        .font(.body)

      Text(suggestion.currentValue.formatted(currency: currency))
        .font(.body).monospacedDigit()

      Text(suggestion.currentPercentage.formattedPercentage())
        .font(.body).monospacedDigit()

      Text(suggestion.targetPercentage.formattedPercentage())
        .font(.body).monospacedDigit()

      Text(suggestion.difference.formatted(currency: currency))
        .font(.body).monospacedDigit()

      HStack(spacing: 4) {
        if suggestion.actionType != .noAction {
          Image(
            systemName: suggestion.actionType == .buy
              ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
          )
          .font(.caption)
        }
        Text(suggestion.actionText)
      }
      .font(.body)
      .foregroundStyle(actionColor(for: suggestion.actionType))
    }
  }

  // MARK: - No Target Section

  private var noTargetSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("No Target Set")
        .font(.headline)

      Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
        GridRow {
          Text("Category").font(.caption).foregroundStyle(.secondary)
          Text("Current Value").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          Text("Current %").font(.caption).foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
        }

        Divider()
          .gridCellUnsizedAxes(.horizontal)

        ForEach(viewModel.noTargetRows) { row in
          noTargetRow(row)
        }
      }
    }
  }

  private func noTargetRow(_ row: NoTargetRowData) -> some View {
    GridRow {
      Text(row.categoryName)
        .font(.body)

      Text(row.currentValue.formatted(currency: SettingsService.shared.mainCurrency))
        .font(.body).monospacedDigit()

      Text(row.currentPercentage.formattedPercentage())
        .font(.body).monospacedDigit()
    }
  }

  // MARK: - Uncategorized Section

  private var uncategorizedSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Uncategorized")
        .font(.headline)

      if let uncategorized = viewModel.uncategorizedRow {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
          GridRow {
            Text("Category").font(.caption).foregroundStyle(.secondary)
            Text("Current Value").font(.caption).foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
            Text("Current %").font(.caption).foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
            Text("Target %").font(.caption).foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
            Text("Action").font(.caption).foregroundStyle(.secondary)
              .gridColumnAlignment(.trailing)
          }

          Divider()
            .gridCellUnsizedAxes(.horizontal)

          GridRow {
            Text("Uncategorized")
              .font(.body)

            Text(
              uncategorized.currentValue.formatted(
                currency: SettingsService.shared.mainCurrency)
            )
            .font(.body).monospacedDigit()

            Text(uncategorized.currentPercentage.formattedPercentage())
              .font(.body).monospacedDigit()

            Text("\u{2014}")
              .font(.body)
              .foregroundStyle(.secondary)

            Text("N/A")
              .font(.body)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  // MARK: - Summary Section

  private var summarySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Suggested Moves")
        .font(.headline)

      ForEach(viewModel.summaryTexts, id: \.self) { text in
        Text(text)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    EmptyStateView(
      icon: "chart.bar.doc.horizontal",
      title: "No Rebalancing Data",
      message: "Set target allocations on your categories to use the rebalancing calculator."
    )
  }

  // MARK: - Helpers

  private func actionColor(for actionType: RebalancingActionType) -> Color {
    switch actionType {
    case .buy:
      return .green

    case .sell:
      return .red

    case .noAction:
      return .secondary
    }
  }
}

// MARK: - Previews

#Preview("Rebalancing") {
  NavigationStack {
    RebalancingView(modelContext: PreviewContainer.container.mainContext)
  }
}

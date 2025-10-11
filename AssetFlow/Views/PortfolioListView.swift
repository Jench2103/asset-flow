//
//  PortfolioListView.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/10.
//

import SwiftUI

/// Portfolio List View - Displays all portfolios
///
/// Primary platform: macOS
/// This view shows a list of all portfolios with their names and descriptions.
/// It includes an empty state for when no portfolios exist, and a toolbar button
/// to add new portfolios.
struct PortfolioListView: View {
  @State private var viewModel = PortfolioListViewModel()
  @State private var showingAddPortfolio = false

  var body: some View {
    NavigationStack {
      Group {
        if viewModel.portfolios.isEmpty {
          emptyStateView
        } else {
          portfolioListContent
        }
      }
      .navigationTitle("Portfolios")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Portfolio") {
            showingAddPortfolio = true
          }
          .accessibilityIdentifier("Add Portfolio")
        }
      }
      .navigationDestination(isPresented: $showingAddPortfolio) {
        AddPortfolioView()
      }
    }
  }

  // MARK: - Portfolio List Content

  private var portfolioListContent: some View {
    List {
      ForEach(viewModel.portfolios, id: \.id) { portfolio in
        PortfolioRowView(portfolio: portfolio)
          .accessibilityIdentifier("Portfolio-\(portfolio.name)")
      }
    }
    .accessibilityIdentifier("Portfolio List")
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 24) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 64))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("Empty State Icon")

      VStack(spacing: 8) {
        Text("No portfolios yet")
          .font(.title2)
          .fontWeight(.semibold)
          .accessibilityIdentifier("No portfolios yet")

        Text("Add your first portfolio to get started")
          .font(.body)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("Add your first portfolio to get started")
      }

      Button {
        showingAddPortfolio = true
      } label: {
        Label("Add Portfolio", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("Add Portfolio Empty State")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

// MARK: - Portfolio Row View

/// Individual row for displaying a portfolio in the list
private struct PortfolioRowView: View {
  let portfolio: Portfolio

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(portfolio.name)
        .font(.headline)
        .accessibilityIdentifier(portfolio.name)

      if let description = portfolio.portfolioDescription {
        Text(description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(description)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Add Portfolio View (Placeholder)

/// Placeholder view for adding a new portfolio
///
/// This is a temporary implementation to satisfy navigation tests.
/// Full implementation will be in Issue #02.
private struct AddPortfolioView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      Section {
        Text("Portfolio form will be implemented in Issue #02")
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Add Portfolio")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
        .accessibilityIdentifier("Cancel")
      }

      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          // TODO: Implement save logic in Issue #02
          dismiss()
        }
        .accessibilityIdentifier("Save")
      }
    }
  }
}

// MARK: - Previews

#Preview("With Portfolios") {
  PortfolioListView()
}

#Preview("Empty State") {
  PortfolioListView()
}

//
//  PortfolioListView.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/10.
//

import SwiftData
import SwiftUI

/// Portfolio List View - Displays all portfolios
///
/// Primary platform: macOS
/// This view shows a list of all portfolios with their names and descriptions.
/// It includes an empty state for when no portfolios exist, and a toolbar button
/// to add new portfolios.
struct PortfolioListView: View {
  @State var viewModel: PortfolioListViewModel
  @Environment(\.modelContext) private var modelContext
  @State private var showingAddPortfolioSheet = false

  @Query(sort: \Portfolio.name) private var portfolios: [Portfolio]

  var body: some View {
    NavigationStack {
      Group {
        if portfolios.isEmpty {
          emptyStateView
        } else {
          portfolioListContent
        }
      }
      .navigationTitle("Portfolios")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Portfolio") {
            showingAddPortfolioSheet = true
          }
          .accessibilityIdentifier("Add Portfolio")
        }
      }
      .sheet(isPresented: $showingAddPortfolioSheet) {
        NavigationStack {
          let formViewModel = PortfolioFormViewModel(modelContext: modelContext)
          PortfolioFormView(viewModel: formViewModel)
        }
      }
      .alert(
        "Delete Portfolio?",
        isPresented: $viewModel.showingDeleteConfirmation,
        presenting: viewModel.portfolioToDelete
      ) { _ in
        Button("Cancel", role: .cancel) {
          viewModel.cancelDelete()
        }
        Button("Delete", role: .destructive) {
          viewModel.confirmDelete()
        }
      } message: { portfolio in
        Text("Are you sure you want to delete '\(portfolio.name)'? This action cannot be undone.")
      }
      .alert(
        "Cannot Delete Portfolio",
        isPresented: $viewModel.showingDeletionError,
        presenting: viewModel.deletionError
      ) { _ in
        Button("OK", role: .cancel) {
          viewModel.deletionError = nil
        }
      } message: { error in
        VStack {
          if let description = error.errorDescription {
            Text(description)
          }
          if let suggestion = error.recoverySuggestion {
            Text("\n\(suggestion)")
          }
        }
      }
    }
  }

  // MARK: - Portfolio List Content

  private var portfolioListContent: some View {
    List {
      ForEach(portfolios) { portfolio in
        NavigationLink(value: portfolio) {
          PortfolioRowView(portfolio: portfolio)
            .accessibilityIdentifier("Portfolio-\(portfolio.name)")
        }
        .contextMenu {
          Button(role: .destructive) {
            viewModel.initiateDelete(portfolio: portfolio)
          } label: {
            Label("Delete Portfolio", systemImage: "trash")
          }
          .accessibilityIdentifier("Delete Portfolio Context Menu")
        }
      }
    }
    .navigationDestination(for: Portfolio.self) { portfolio in
      let formViewModel = PortfolioFormViewModel(modelContext: modelContext, portfolio: portfolio)
      PortfolioFormView(viewModel: formViewModel)
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
        showingAddPortfolioSheet = true
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

// MARK: - Previews

#Preview("With Portfolios") {
  let container = PreviewContainer.container
  let context = container.mainContext

  // Add mock data for preview
  context.insert(Portfolio(name: "Tech Stocks", portfolioDescription: "High-growth tech portfolio"))
  context.insert(Portfolio(name: "Real Estate", portfolioDescription: "Residential properties"))

  let viewModel = PortfolioListViewModel(modelContext: context)

  return PortfolioListView(viewModel: viewModel)
    .modelContainer(container)
}

#Preview("Empty State") {
  let container = PreviewContainer.container
  let viewModel = PortfolioListViewModel(modelContext: container.mainContext)

  return PortfolioListView(viewModel: viewModel)
    .modelContainer(container)
}

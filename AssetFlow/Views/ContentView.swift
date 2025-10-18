//
//  ContentView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

/// Main content view with sidebar navigation for macOS
///
/// Provides sidebar navigation with:
/// - Overview (default page)
/// - All Portfolios collection
/// - Individual portfolio items
struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Portfolio.name) private var portfolios: [Portfolio]

  @State private var selectedSidebarItem: SidebarItem? = .overview
  @State private var portfolioToEdit: Portfolio?
  @State private var viewModel: PortfolioManagementViewModel?

  init() {
    // ViewModel will be initialized in body when modelContext is available
  }

  var body: some View {
    NavigationSplitView {
      // Sidebar
      sidebar
    } detail: {
      // Detail view based on selection
      detailView
    }
    .onAppear {
      // Initialize viewModel when modelContext becomes available
      if viewModel == nil {
        viewModel = PortfolioManagementViewModel(modelContext: modelContext)
      }
    }
    .sheet(item: $portfolioToEdit) { portfolio in
      NavigationStack {
        let formViewModel = PortfolioFormViewModel(modelContext: modelContext, portfolio: portfolio)
        PortfolioFormView(viewModel: formViewModel)
      }
    }
    .alert(
      "Delete Portfolio?",
      isPresented: Binding(
        get: { viewModel?.showingDeleteConfirmation ?? false },
        set: { if !$0 { viewModel?.cancelDelete() } }
      ),
      presenting: viewModel?.portfolioToDelete
    ) { _ in
      Button("Cancel", role: .cancel) {
        viewModel?.cancelDelete()
      }
      Button("Delete", role: .destructive) {
        viewModel?.confirmDelete()
      }
    } message: { portfolio in
      Text("Are you sure you want to delete '\(portfolio.name)'? This action cannot be undone.")
    }
    .alert(
      "Cannot Delete Portfolio",
      isPresented: Binding(
        get: { viewModel?.showingDeletionError ?? false },
        set: { if !$0 { viewModel?.deletionError = nil } }
      ),
      presenting: viewModel?.deletionError
    ) { _ in
      Button("OK", role: .cancel) {
        viewModel?.deletionError = nil
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

  // MARK: - Sidebar

  private var sidebar: some View {
    List(selection: $selectedSidebarItem) {
      // Overview section
      Section {
        NavigationLink(value: SidebarItem.overview) {
          Label("Overview", systemImage: "chart.pie.fill")
        }
        .accessibilityIdentifier("Overview Sidebar Item")
      }

      // Portfolios section
      Section("Portfolios") {
        ForEach(portfolios) { portfolio in
          NavigationLink(value: SidebarItem.portfolio(portfolio)) {
            Label(portfolio.name, systemImage: "folder")
          }
          .accessibilityIdentifier("Portfolio Sidebar Item-\(portfolio.name)")
          .contextMenu {
            Button {
              portfolioToEdit = portfolio
            } label: {
              Label("Edit Portfolio", systemImage: "pencil")
            }
            .accessibilityIdentifier("Edit Portfolio Sidebar Context Menu-\(portfolio.name)")

            Button(role: .destructive) {
              viewModel?.initiateDelete(portfolio: portfolio)
            } label: {
              Label("Delete Portfolio", systemImage: "trash")
            }
            .accessibilityIdentifier("Delete Portfolio Sidebar Context Menu-\(portfolio.name)")
          }
        }
      }
    }
    .navigationTitle("AssetFlow")
    .accessibilityIdentifier("Sidebar")
  }

  // MARK: - Detail View

  @ViewBuilder
  private var detailView: some View {
    if let selectedSidebarItem {
      switch selectedSidebarItem {
      case .overview:
        OverviewView()

      case .portfolio(let portfolio):
        let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: modelContext)
        PortfolioDetailView(viewModel: viewModel)
          .id(portfolio.id)
      }
    } else {
      // Default to overview if nothing selected
      OverviewView()
    }
  }
}

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
  case overview
  case portfolio(Portfolio)

  // Make Portfolio hashable for this enum
  func hash(into hasher: inout Hasher) {
    switch self {
    case .overview:
      hasher.combine("overview")

    case .portfolio(let portfolio):
      hasher.combine("portfolio")
      hasher.combine(portfolio.id)
    }
  }

  static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
    switch (lhs, rhs) {
    case (.overview, .overview):
      return true

    case (.portfolio(let lhsPortfolio), .portfolio(let rhsPortfolio)):
      return lhsPortfolio.id == rhsPortfolio.id

    default:
      return false
    }
  }
}

// MARK: - Previews

#Preview("With Portfolios") {
  let container = PreviewContainer.container
  let context = container.mainContext

  // Create sample portfolios
  let tech = Portfolio(name: "Tech Stocks", portfolioDescription: "High-growth tech portfolio")
  let realestate = Portfolio(name: "Real Estate", portfolioDescription: "Residential properties")
  context.insert(tech)
  context.insert(realestate)

  return ContentView()
    .modelContainer(container)
}

#Preview("Empty") {
  let container = PreviewContainer.container

  return ContentView()
    .modelContainer(container)
}

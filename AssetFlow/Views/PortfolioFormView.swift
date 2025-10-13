//
//  PortfolioFormView.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/13.
//

import SwiftData
import SwiftUI

/// A view that presents a form for creating or editing a portfolio.
///
/// This view binds to a `PortfolioFormViewModel` to manage its state,
/// handle user input, and perform validation.
struct PortfolioFormView: View {
  /// The ViewModel that manages the form's state and logic.
  @State var viewModel: PortfolioFormViewModel
  /// The presentation mode environment value, used to dismiss the view.
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      Section(header: Text("Portfolio Details")) {
        TextField("Name", text: $viewModel.name)

        if let validationMessage = viewModel.nameValidationMessage {
          Text(validationMessage)
            .font(.caption)
            .foregroundStyle(.red)
        }

        TextField("Description", text: $viewModel.portfolioDescription, axis: .vertical)
          .lineLimit(5...)
      }
    }
    .navigationTitle(viewModel.isEditing ? "Edit Portfolio" : "New Portfolio")
    #if os(macOS)
      .padding()
      .frame(minWidth: 300, minHeight: 200)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          dismiss()
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          viewModel.save()
          dismiss()
        }
        .disabled(viewModel.isSaveDisabled)
      }
    }
  }
}

// MARK: - Previews

#Preview("New Portfolio") {
  NavigationStack {
    let viewModel = PortfolioFormViewModel(modelContext: PreviewContainer.container.mainContext)
    PortfolioFormView(viewModel: viewModel)
  }
  .modelContainer(PreviewContainer.container)
}

#Preview("Editing Portfolio") {
  let context = PreviewContainer.container.mainContext
  let portfolio = Portfolio(name: "Existing Portfolio", portfolioDescription: "Some description")
  context.insert(portfolio)

  let viewModel = PortfolioFormViewModel(modelContext: context, portfolio: portfolio)

  return NavigationStack {
    PortfolioFormView(viewModel: viewModel)
  }
  .modelContainer(PreviewContainer.container)
}

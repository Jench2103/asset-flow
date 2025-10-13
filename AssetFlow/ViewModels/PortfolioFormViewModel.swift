//
//  PortfolioFormViewModel.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/13.
//

import Foundation
import Observation
import SwiftData

/// Manages the state and validation for the portfolio creation and editing form.
///
/// This ViewModel holds the form data, performs real-time validation on the portfolio name,
/// and handles the logic for saving a new or existing `Portfolio` to the `ModelContext`.
@Observable
@MainActor
class PortfolioFormViewModel {
  // MARK: - Form Properties

  /// The name of the portfolio. This property is validated in real-time.
  var name: String {
    didSet {
      // Only trigger updates if the value actually changed.
      guard name != oldValue else { return }
      hasUserInteracted = true
      validateName()
    }
  }

  /// The optional description for the portfolio.
  var portfolioDescription: String

  /// A message describing a validation error for the `name` property. A `nil` value indicates the name is valid.
  var nameValidationMessage: String?
  /// A message describing a non-critical warning for the `name` property.
  var nameWarningMessage: String?
  /// Tracks if the user has modified the name field, to delay validation messages.
  var hasUserInteracted: Bool = false

  // MARK: - Private State

  private var modelContext: ModelContext
  private var portfolio: Portfolio?

  // MARK: - Computed Properties

  /// Returns `true` if the ViewModel is editing an existing portfolio, `false` otherwise.
  var isEditing: Bool {
    portfolio != nil
  }

  /// Returns `true` if the form is in an invalid state and should not be saved.
  var isSaveDisabled: Bool {
    // The save button is disabled if there is any validation error message.
    nameValidationMessage != nil
  }

  // MARK: - Initializer

  /// Initializes the ViewModel.
  ///
  /// - Parameters:
  ///   - modelContext: The `ModelContext` used for saving and validating the portfolio.
  ///   - portfolio: The portfolio to edit. If `nil`, the ViewModel is configured to create a new portfolio.
  init(modelContext: ModelContext, portfolio: Portfolio? = nil) {
    self.modelContext = modelContext
    self.portfolio = portfolio

    // Initialize properties.
    self.name = portfolio?.name ?? ""
    self.portfolioDescription = portfolio?.portfolioDescription ?? ""

    // Perform initial validation to set the initial state of `isSaveDisabled`.
    // This may be redundant if property observers fire, but it ensures correctness.
    validateName()
  }

  // MARK: - Public Methods

  /// Saves the portfolio to the `ModelContext`.
  ///
  /// If editing, this method updates the existing portfolio. If creating, it inserts a new portfolio.
  /// The method assumes validation has already passed, as the save button is disabled otherwise.
  func save() {
    let description = portfolioDescription.isEmpty ? nil : portfolioDescription
    if let portfolio = portfolio {
      // Editing existing portfolio
      portfolio.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      portfolio.portfolioDescription = description
    } else {
      // Creating new portfolio
      let newPortfolio = Portfolio(
        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
        portfolioDescription: description)
      modelContext.insert(newPortfolio)
    }
  }

  // MARK: - Private Validation

  private func validateName() {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    // 1. Check for and set whitespace warning
    if !trimmedName.isEmpty && name != trimmedName {
      nameWarningMessage = "Leading and trailing spaces will be automatically trimmed."
    } else {
      nameWarningMessage = nil
    }

    // 2. Check for validation errors (which override warnings)
    if trimmedName.isEmpty {
      nameValidationMessage = "Portfolio name cannot be empty."
      return
    }

    // Uniqueness Check
    let fetchDescriptor = FetchDescriptor<Portfolio>()
    guard let portfolios = try? modelContext.fetch(fetchDescriptor) else {
      // If fetch fails, play it safe and disable saving.
      nameValidationMessage = "Could not verify portfolio name."
      return
    }

    let isDuplicate = portfolios.contains { existingPortfolio in
      // Case-insensitive comparison
      let namesMatch =
        existingPortfolio.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame

      // If we are editing, the duplicate name is only a problem
      // if it belongs to a *different* portfolio.
      if isEditing, let portfolio = portfolio {
        return namesMatch && existingPortfolio.id != portfolio.id
      }

      // If we are creating a new portfolio, any match is a duplicate.
      return namesMatch
    }

    if isDuplicate {
      nameValidationMessage = "A portfolio with this name already exists."
    } else {
      nameValidationMessage = nil
    }
  }
}

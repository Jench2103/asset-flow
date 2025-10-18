//
//  AssetFormViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import Observation
import SwiftData

/// Manages the state and validation for the asset creation and editing form.
///
/// This ViewModel holds the form data, performs real-time validation on asset fields,
/// and handles the logic for saving a new or existing `Asset` to the `ModelContext`.
@Observable
@MainActor
class AssetFormViewModel {
  // MARK: - Form Properties

  /// The name of the asset. This property is validated in real-time.
  var name: String {
    didSet {
      guard name != oldValue else { return }
      hasUserInteracted = true
      validateName()
    }
  }

  /// The type of asset (stock, bond, crypto, etc.)
  var assetType: AssetType

  /// The quantity held as a string for text field binding
  var quantity: String {
    didSet {
      guard quantity != oldValue else { return }
      hasQuantityInteraction = true
      validateQuantity()
    }
  }

  /// The current value/price as a string for text field binding
  var currentValue: String {
    didSet {
      guard currentValue != oldValue else { return }
      hasCurrentValueInteraction = true
      validateCurrentValue()
    }
  }

  /// Optional notes about the asset
  var notes: String

  /// Currency code (e.g., "USD", "EUR")
  var currency: String

  // MARK: - Validation Messages

  /// Validation message for the name field
  var nameValidationMessage: String?

  /// Validation message for the quantity field
  var quantityValidationMessage: String?

  /// Validation message for the current value field
  var currentValueValidationMessage: String?

  /// Tracks if the user has interacted with the name field
  var hasUserInteracted: Bool = false

  /// Tracks if the user has interacted with the quantity field
  var hasQuantityInteraction: Bool = false

  /// Tracks if the user has interacted with the current value field
  var hasCurrentValueInteraction: Bool = false

  // MARK: - Private State

  private var modelContext: ModelContext
  private var portfolio: Portfolio
  private var asset: Asset?

  // MARK: - Computed Properties

  /// Returns true if editing an existing asset
  var isEditing: Bool {
    asset != nil
  }

  /// Returns true if the form has validation errors
  var isSaveDisabled: Bool {
    nameValidationMessage != nil || quantityValidationMessage != nil
      || currentValueValidationMessage != nil
  }

  // MARK: - Initializer

  /// Initializes the ViewModel for creating a new asset or editing an existing one.
  ///
  /// - Parameters:
  ///   - modelContext: The `ModelContext` for data persistence
  ///   - portfolio: The portfolio this asset belongs to
  ///   - asset: The asset to edit (nil for new asset)
  init(modelContext: ModelContext, portfolio: Portfolio, asset: Asset? = nil) {
    self.modelContext = modelContext
    self.portfolio = portfolio
    self.asset = asset

    // Initialize properties
    self.name = asset?.name ?? ""
    self.assetType = asset?.assetType ?? .stock
    self.currency = asset?.currency ?? "USD"
    self.notes = asset?.notes ?? ""

    // For editing, populate quantity and current value from existing data
    if let asset = asset {
      self.quantity = asset.quantity.description
      self.currentValue = asset.currentPrice.description
    } else {
      self.quantity = ""
      self.currentValue = ""
    }

    // Perform initial validation
    validateName()
    validateQuantity()
    validateCurrentValue()
  }

  // MARK: - Public Methods

  /// Saves the asset to the ModelContext.
  ///
  /// For new assets, creates an initial transaction and price history.
  /// For existing assets, updates the asset properties only (not quantity/price).
  func save() {
    if let asset = asset {
      // Update existing asset
      asset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      asset.assetType = assetType
      asset.notes = notes.isEmpty ? nil : notes
      asset.currency = currency
      // Note: Quantity and price are managed through transactions for existing assets
    } else {
      // Create new asset
      let newAsset = Asset(
        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
        assetType: assetType,
        currency: currency,
        notes: notes.isEmpty ? nil : notes,
        portfolio: portfolio
      )
      modelContext.insert(newAsset)

      // Create initial transaction
      if let quantityValue = Decimal(string: quantity),
        let priceValue = Decimal(string: currentValue)
      {
        let totalAmount = quantityValue * priceValue
        let transaction = Transaction(
          transactionType: .buy,
          transactionDate: Date(),
          quantity: quantityValue,
          pricePerUnit: priceValue,
          totalAmount: totalAmount,
          asset: newAsset
        )
        modelContext.insert(transaction)

        // Create initial price history
        let priceHistory = PriceHistory(
          date: Date(),
          price: priceValue,
          asset: newAsset
        )
        modelContext.insert(priceHistory)
      }
    }
  }

  // MARK: - Private Validation

  private func validateName() {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedName.isEmpty {
      nameValidationMessage = "Asset name cannot be empty."
      return
    }

    nameValidationMessage = nil
  }

  private func validateQuantity() {
    // When editing, quantity is read-only (managed via transactions)
    if isEditing {
      quantityValidationMessage = nil
      return
    }

    let trimmedQuantity = quantity.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedQuantity.isEmpty {
      quantityValidationMessage = "Quantity is required."
      return
    }

    guard let quantityValue = Decimal(string: trimmedQuantity) else {
      quantityValidationMessage = "Quantity must be a valid number."
      return
    }

    if quantityValue <= 0 {
      quantityValidationMessage = "Quantity must be greater than zero."
      return
    }

    quantityValidationMessage = nil
  }

  private func validateCurrentValue() {
    // When editing, current value is read-only (managed via price history)
    if isEditing {
      currentValueValidationMessage = nil
      return
    }

    let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedValue.isEmpty {
      currentValueValidationMessage = "Current value is required."
      return
    }

    guard let valueDecimal = Decimal(string: trimmedValue) else {
      currentValueValidationMessage = "Current value must be a valid number."
      return
    }

    if valueDecimal < 0 {
      currentValueValidationMessage = "Current value must be zero or greater."
      return
    }

    currentValueValidationMessage = nil
  }
}

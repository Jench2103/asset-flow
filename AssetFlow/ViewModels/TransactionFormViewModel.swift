//
//  TransactionFormViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/1/26.
//

import Foundation
import Observation
import SwiftData

/// Manages the state and validation for the transaction creation and editing form.
///
/// This ViewModel holds form data, performs real-time validation on all fields,
/// calculates the total amount, and handles saving new or updated `Transaction` records.
@Observable
@MainActor
class TransactionFormViewModel {
  // MARK: - Form Properties

  /// The type of transaction. Changing this re-validates quantity for sell/transferOut.
  var transactionType: TransactionType {
    didSet {
      guard transactionType != oldValue else { return }
      validateQuantity()
    }
  }

  /// The date of the transaction. Validated on change.
  var transactionDate: Date {
    didSet {
      guard transactionDate != oldValue else { return }
      hasDateInteraction = true
      validateDate()
    }
  }

  /// The quantity as a string for text field binding. Validated on change.
  var quantityText: String {
    didSet {
      guard quantityText != oldValue else { return }
      hasQuantityInteraction = true
      validateQuantity()
    }
  }

  /// The price per unit as a string for text field binding. Validated on change.
  var pricePerUnitText: String {
    didSet {
      guard pricePerUnitText != oldValue else { return }
      hasPricePerUnitInteraction = true
      validatePricePerUnit()
    }
  }

  // MARK: - Validation Messages

  /// Validation message for the date field
  var dateValidationMessage: String?

  /// Validation message for the quantity field
  var quantityValidationMessage: String?

  /// Validation message for the price per unit field
  var pricePerUnitValidationMessage: String?

  // MARK: - Interaction Flags

  /// Tracks if the user has interacted with the date field
  var hasDateInteraction: Bool = false

  /// Tracks if the user has interacted with the quantity field
  var hasQuantityInteraction: Bool = false

  /// Tracks if the user has interacted with the price per unit field
  var hasPricePerUnitInteraction: Bool = false

  // MARK: - Private State

  private var modelContext: ModelContext
  let asset: Asset
  private let existingTransaction: Transaction?

  // MARK: - Computed Properties

  /// Whether this is an edit operation on an existing transaction
  var isEditing: Bool {
    existingTransaction != nil
  }

  /// Navigation title based on editing state
  var navigationTitle: String {
    isEditing
      ? String(localized: "Edit Transaction", table: "Transaction")
      : String(localized: "Record Transaction", table: "Transaction")
  }

  /// Whether this asset is a cash type (price is always 1)
  var isCashAsset: Bool {
    asset.assetType == .cash
  }

  /// Returns true if the form has validation errors
  var isSaveDisabled: Bool {
    dateValidationMessage != nil
      || quantityValidationMessage != nil
      || pricePerUnitValidationMessage != nil
  }

  /// The calculated total amount (quantity * pricePerUnit), or nil if inputs are invalid
  var calculatedTotalAmount: Decimal? {
    let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedPrice = pricePerUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let quantity = Decimal(string: trimmedQuantity),
      let price = Decimal(string: trimmedPrice)
    else {
      return nil
    }
    return quantity * price
  }

  // MARK: - Initializer

  /// Initializes the ViewModel for creating or editing a transaction.
  ///
  /// - Parameters:
  ///   - modelContext: The `ModelContext` for data persistence
  ///   - asset: The asset this transaction belongs to
  ///   - transaction: The existing transaction to edit (nil for new transaction)
  init(modelContext: ModelContext, asset: Asset, transaction: Transaction? = nil) {
    self.modelContext = modelContext
    self.asset = asset
    self.existingTransaction = transaction

    if let transaction = transaction {
      // Edit mode: pre-populate from existing transaction
      self.transactionType = transaction.transactionType
      self.transactionDate = transaction.transactionDate
      self.quantityText = "\(transaction.quantity)"

      if asset.assetType == .cash {
        self.pricePerUnitText = "1"
      } else {
        self.pricePerUnitText = "\(transaction.pricePerUnit)"
      }

      // In edit mode, show validation messages immediately
      self.hasDateInteraction = true
      self.hasQuantityInteraction = true
      self.hasPricePerUnitInteraction = true
    } else {
      // Create mode: set defaults
      self.transactionType = .buy
      self.transactionDate = Date()
      self.quantityText = ""

      // Cash assets always have price per unit = 1
      if asset.assetType == .cash {
        self.pricePerUnitText = "1"
      } else {
        // Pre-fill price with asset's current price if available
        let currentPrice = asset.currentPrice
        self.pricePerUnitText = currentPrice > 0 ? "\(currentPrice)" : ""
      }
    }

    // Perform initial validation
    validateDate()
    validateQuantity()
    validatePricePerUnit()
  }

  // MARK: - Public Methods

  /// Returns a user-friendly display name for a transaction type.
  ///
  /// For cash assets, "Buy" becomes "Deposit" and "Sell" becomes "Withdrawal".
  func displayName(for type: TransactionType) -> String {
    if asset.assetType == .cash {
      switch type {
      case .buy: return String(localized: "Deposit", table: "Transaction")
      case .sell: return String(localized: "Withdrawal", table: "Transaction")
      default: return type.localizedName
      }
    }
    return type.localizedName
  }

  /// Saves the transaction to the ModelContext.
  ///
  /// For new transactions, creates a new `Transaction` linked to the asset.
  /// For existing transactions, updates the record in-place.
  func save() {
    guard !isSaveDisabled else { return }
    let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let quantity = Decimal(string: trimmedQuantity) else { return }

    // Cash assets always use price per unit = 1
    let pricePerUnit: Decimal
    if asset.assetType == .cash {
      pricePerUnit = 1
    } else {
      let trimmedPrice = pricePerUnitText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard let parsedPrice = Decimal(string: trimmedPrice) else { return }
      pricePerUnit = parsedPrice
    }

    let totalAmount = quantity * pricePerUnit

    if let existing = existingTransaction {
      // Update existing transaction in-place
      existing.transactionType = transactionType
      existing.transactionDate = transactionDate
      existing.quantity = quantity
      existing.pricePerUnit = pricePerUnit
      existing.totalAmount = totalAmount
    } else {
      // Create new transaction
      let transaction = Transaction(
        transactionType: transactionType,
        transactionDate: transactionDate,
        quantity: quantity,
        pricePerUnit: pricePerUnit,
        totalAmount: totalAmount,
        currency: asset.currency,
        asset: asset
      )
      modelContext.insert(transaction)
    }
  }

  // MARK: - Private Validation

  private func validateDate() {
    if Calendar.current.startOfDay(for: transactionDate)
      > Calendar.current.startOfDay(for: Date())
    {
      dateValidationMessage = String(
        localized: "Date cannot be in the future.", table: "Transaction")
      return
    }
    dateValidationMessage = nil
  }

  private func validateQuantity() {
    let trimmed = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)

    let isCash = asset.assetType == .cash

    if trimmed.isEmpty {
      quantityValidationMessage =
        isCash
        ? String(localized: "Amount is required.", table: "Transaction")
        : String(localized: "Quantity is required.", table: "Transaction")
      return
    }

    guard let quantityValue = Decimal(string: trimmed) else {
      quantityValidationMessage =
        isCash
        ? String(localized: "Amount must be a valid number.", table: "Transaction")
        : String(localized: "Quantity must be a valid number.", table: "Transaction")
      return
    }

    if quantityValue <= 0 {
      quantityValidationMessage =
        isCash
        ? String(localized: "Amount must be greater than zero.", table: "Transaction")
        : String(localized: "Quantity must be greater than zero.", table: "Transaction")
      return
    }

    if isEditing {
      // Edit mode: check that resulting quantity is >= 0
      // baseQuantity = current quantity without the existing transaction's impact
      let baseQuantity = asset.quantity - (existingTransaction?.quantityImpact ?? 0)
      // newImpact = the impact of the edited transaction
      let newImpact: Decimal
      switch transactionType {
      case .sell, .transferOut:
        newImpact = -quantityValue

      case .buy, .transferIn, .adjustment, .dividend, .interest:
        newImpact = quantityValue
      }
      let resultingQuantity = baseQuantity + newImpact
      if resultingQuantity < 0 {
        if transactionType == .sell {
          quantityValidationMessage = String(
            localized:
              "Cannot sell more than available holdings (\(String(describing: baseQuantity))).",
            table: "Transaction")
        } else if transactionType == .transferOut {
          quantityValidationMessage = String(
            localized:
              "Cannot transfer out more than available holdings (\(String(describing: baseQuantity))).",
            table: "Transaction")
        } else {
          quantityValidationMessage = String(
            localized: "This change would cause the asset quantity to become negative.",
            table: "Transaction")
        }
        return
      }
    } else {
      // Create mode: sell/transferOut quantity validation
      if transactionType == .sell {
        let currentHoldings = asset.quantity
        if quantityValue > currentHoldings {
          quantityValidationMessage = String(
            localized:
              "Cannot sell more than current holdings (\(String(describing: currentHoldings))).",
            table: "Transaction")
          return
        }
      } else if transactionType == .transferOut {
        let currentHoldings = asset.quantity
        if quantityValue > currentHoldings {
          quantityValidationMessage = String(
            localized:
              "Cannot transfer out more than current holdings (\(String(describing: currentHoldings))).",
            table: "Transaction")
          return
        }
      }
    }

    quantityValidationMessage = nil
  }

  private func validatePricePerUnit() {
    // Cash assets always have price per unit = 1; no validation needed
    if asset.assetType == .cash {
      pricePerUnitValidationMessage = nil
      return
    }

    let trimmed = pricePerUnitText.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
      pricePerUnitValidationMessage = String(
        localized: "Price per unit is required.", table: "Transaction")
      return
    }

    guard let priceValue = Decimal(string: trimmed) else {
      pricePerUnitValidationMessage = String(
        localized: "Price per unit must be a valid number.", table: "Transaction")
      return
    }

    if priceValue < 0 {
      pricePerUnitValidationMessage = String(
        localized: "Price per unit must be zero or greater.", table: "Transaction")
      return
    }

    pricePerUnitValidationMessage = nil
  }
}

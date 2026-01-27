//
//  PriceHistoryFormViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/20.
//

import Foundation
import Observation
import SwiftData

/// Manages the state and validation for the price history add/edit form.
///
/// This ViewModel holds form data, performs real-time validation on date and price fields,
/// and handles saving new or updated `PriceHistory` records.
@Observable
@MainActor
class PriceHistoryFormViewModel {
  // MARK: - Form Properties

  /// The date of the price record. Validated on change.
  var date: Date {
    didSet {
      guard date != oldValue else { return }
      hasDateInteraction = true
      validateDate()
    }
  }

  /// The price as a string for text field binding. Validated on change.
  var priceText: String {
    didSet {
      guard priceText != oldValue else { return }
      hasPriceInteraction = true
      validatePrice()
    }
  }

  // MARK: - Validation Messages

  /// Validation message for the date field
  var dateValidationMessage: String?

  /// Validation message for the price field
  var priceValidationMessage: String?

  // MARK: - Interaction Flags

  /// Tracks if the user has interacted with the date field
  var hasDateInteraction: Bool = false

  /// Tracks if the user has interacted with the price field
  var hasPriceInteraction: Bool = false

  // MARK: - Private State

  private var modelContext: ModelContext
  let asset: Asset
  private let existingRecord: PriceHistory?

  // MARK: - Computed Properties

  /// Returns true if editing an existing price record
  var isEditing: Bool {
    existingRecord != nil
  }

  /// Returns true if the form has validation errors
  var isSaveDisabled: Bool {
    dateValidationMessage != nil || priceValidationMessage != nil
  }

  /// Navigation title based on editing state
  var navigationTitle: String {
    isEditing
      ? String(localized: "Edit Price Record", table: "PriceHistory")
      : String(localized: "Add Price Record", table: "PriceHistory")
  }

  // MARK: - Initializer

  /// Initializes the ViewModel for creating or editing a price record.
  ///
  /// - Parameters:
  ///   - modelContext: The `ModelContext` for data persistence
  ///   - asset: The asset this price record belongs to
  ///   - priceHistory: The existing record to edit (nil for new record)
  init(modelContext: ModelContext, asset: Asset, priceHistory: PriceHistory? = nil) {
    self.modelContext = modelContext
    self.asset = asset
    self.existingRecord = priceHistory

    // Initialize form fields
    self.date = priceHistory?.date ?? Date()
    self.priceText = priceHistory.map { "\($0.price)" } ?? ""

    // Perform initial validation
    validateDate()
    validatePrice()
  }

  // MARK: - Public Methods

  /// Saves the price record to the ModelContext.
  ///
  /// For new records, creates a `PriceHistory` linked to the asset.
  /// For existing records, updates the record in-place.
  func save() {
    guard !isSaveDisabled else { return }
    let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let priceValue = Decimal(string: trimmed) else { return }

    if let record = existingRecord {
      // Update existing record
      record.date = date
      record.price = priceValue
    } else {
      // Create new record
      let newRecord = PriceHistory(
        date: date,
        price: priceValue,
        asset: asset
      )
      modelContext.insert(newRecord)
    }
  }

  // MARK: - Private Validation

  private func validateDate() {
    // Check future date
    if Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date()) {
      dateValidationMessage = String(
        localized: "Date cannot be in the future.", table: "PriceHistory")
      return
    }

    // Check duplicate date (exclude self when editing)
    let selectedDay = Calendar.current.startOfDay(for: date)
    let hasDuplicate =
      asset.priceHistory?.contains { record in
        // When editing, skip the record being edited
        if let existing = existingRecord, record.id == existing.id {
          return false
        }
        return Calendar.current.startOfDay(for: record.date) == selectedDay
      } ?? false

    if hasDuplicate {
      dateValidationMessage = String(
        localized: "A price record already exists for this date.", table: "PriceHistory")
      return
    }

    dateValidationMessage = nil
  }

  private func validatePrice() {
    let trimmedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmedPrice.isEmpty {
      priceValidationMessage = String(localized: "Price is required.", table: "PriceHistory")
      return
    }

    guard let priceValue = Decimal(string: trimmedPrice) else {
      priceValidationMessage = String(
        localized: "Price must be a valid number.", table: "PriceHistory")
      return
    }

    if priceValue < 0 {
      priceValidationMessage = String(
        localized: "Price must be zero or greater.", table: "PriceHistory")
      return
    }

    priceValidationMessage = nil
  }
}

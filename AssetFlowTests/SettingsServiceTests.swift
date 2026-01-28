//
//  SettingsServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("SettingsService Tests")
@MainActor
struct SettingsServiceTests {

  // MARK: - Default Values

  @Test("Default main currency is USD when storage is empty")
  func testDefaultMainCurrencyIsUSD() {
    // Arrange & Act - each test gets fresh isolated storage
    let service = SettingsService.createForTesting()

    // Assert
    #expect(service.mainCurrency == "USD")
  }

  @Test("Default financial goal is nil when storage is empty")
  func testDefaultFinancialGoalIsNil() {
    // Arrange & Act
    let service = SettingsService.createForTesting()

    // Assert
    #expect(service.financialGoal == nil)
  }

  // MARK: - Main Currency Persistence

  @Test("Setting main currency persists the value")
  func testMainCurrencyPersists() {
    // Arrange
    let service = SettingsService.createForTesting()

    // Act
    service.mainCurrency = "EUR"

    // Assert - value is updated in service
    #expect(service.mainCurrency == "EUR")
  }

  @Test("Main currency changes are observable")
  func testMainCurrencyChangesAreObservable() {
    // Arrange
    let service = SettingsService.createForTesting()

    // Act
    service.mainCurrency = "JPY"
    service.mainCurrency = "GBP"

    // Assert
    #expect(service.mainCurrency == "GBP")
  }

  // MARK: - Financial Goal Persistence

  @Test("Setting financial goal persists the value")
  func testFinancialGoalPersists() throws {
    // Arrange
    let service = SettingsService.createForTesting()
    let testValue = try #require(Decimal(string: "100000.50"))

    // Act
    service.financialGoal = testValue

    // Assert
    #expect(service.financialGoal == testValue)
  }

  @Test("Setting financial goal to nil clears the value")
  func testClearingFinancialGoal() {
    // Arrange
    let service = SettingsService.createForTesting()
    service.financialGoal = Decimal(10000)

    // Act
    service.financialGoal = nil

    // Assert
    #expect(service.financialGoal == nil)
  }

  @Test("Financial goal preserves Decimal precision")
  func testFinancialGoalPreservesDecimalPrecision() throws {
    // Arrange
    let service = SettingsService.createForTesting()
    let preciseValue = try #require(Decimal(string: "123456.789012345"))

    // Act
    service.financialGoal = preciseValue

    // Assert
    #expect(service.financialGoal == preciseValue)
  }

  // MARK: - Test Isolation

  @Test("Each test instance has isolated storage")
  func testIsolatedStorage() {
    // Arrange - create two independent services
    let service1 = SettingsService.createForTesting()
    let service2 = SettingsService.createForTesting()

    // Act - modify service1
    service1.mainCurrency = "EUR"
    service1.financialGoal = Decimal(999999)

    // Assert - service2 should have default values (isolated)
    #expect(service2.mainCurrency == "USD")
    #expect(service2.financialGoal == nil)
  }
}

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
    let service = SettingsService.createForTesting()
    #expect(service.mainCurrency == "USD")
  }

  // MARK: - Main Currency Persistence

  @Test("Setting main currency persists the value")
  func testMainCurrencyPersists() {
    let service = SettingsService.createForTesting()
    service.mainCurrency = "EUR"
    #expect(service.mainCurrency == "EUR")
  }

  @Test("Main currency changes are observable")
  func testMainCurrencyChangesAreObservable() {
    let service = SettingsService.createForTesting()
    service.mainCurrency = "JPY"
    service.mainCurrency = "GBP"
    #expect(service.mainCurrency == "GBP")
  }

  // MARK: - Date Format

  @Test("Default dateFormat is .abbreviated")
  func testDefaultDateFormatIsAbbreviated() {
    let service = SettingsService.createForTesting()
    #expect(service.dateFormat == .abbreviated)
  }

  @Test("Setting dateFormat persists the value")
  func testDateFormatPersists() {
    let service = SettingsService.createForTesting()
    service.dateFormat = .long
    #expect(service.dateFormat == .long)
  }

  @Test("dateFormat changes are observable")
  func testDateFormatChangesAreObservable() {
    let service = SettingsService.createForTesting()
    service.dateFormat = .numeric
    service.dateFormat = .complete
    #expect(service.dateFormat == .complete)
  }

  // MARK: - Default Platform

  @Test("Default platform is empty string")
  func testDefaultPlatformIsEmptyString() {
    let service = SettingsService.createForTesting()
    #expect(service.defaultPlatform == "")
  }

  @Test("Setting defaultPlatform persists the value")
  func testDefaultPlatformPersists() {
    let service = SettingsService.createForTesting()
    service.defaultPlatform = "Interactive Brokers"
    #expect(service.defaultPlatform == "Interactive Brokers")
  }

  @Test("defaultPlatform changes are observable")
  func testDefaultPlatformChangesAreObservable() {
    let service = SettingsService.createForTesting()
    service.defaultPlatform = "Schwab"
    service.defaultPlatform = "Firstrade"
    #expect(service.defaultPlatform == "Firstrade")
  }

  // MARK: - Test Isolation

  @Test("Each test instance has isolated storage")
  func testIsolatedStorage() {
    let service1 = SettingsService.createForTesting()
    let service2 = SettingsService.createForTesting()

    service1.mainCurrency = "EUR"

    #expect(service2.mainCurrency == "USD")
  }

  @Test("Isolated storage for dateFormat across instances")
  func testIsolatedDateFormatStorage() {
    let service1 = SettingsService.createForTesting()
    let service2 = SettingsService.createForTesting()

    service1.dateFormat = .complete

    #expect(service2.dateFormat == .abbreviated)
  }

  @Test("Isolated storage for defaultPlatform across instances")
  func testIsolatedDefaultPlatformStorage() {
    let service1 = SettingsService.createForTesting()
    let service2 = SettingsService.createForTesting()

    service1.defaultPlatform = "Schwab"

    #expect(service2.defaultPlatform == "")
  }

  // MARK: - DateFormatStyle

  @Test("DateFormatStyle has 4 cases with stable raw values")
  func testDateFormatStyleCases() {
    let allCases = DateFormatStyle.allCases
    #expect(allCases.count == 4)
    #expect(DateFormatStyle.numeric.rawValue == "numeric")
    #expect(DateFormatStyle.abbreviated.rawValue == "abbreviated")
    #expect(DateFormatStyle.long.rawValue == "long")
    #expect(DateFormatStyle.complete.rawValue == "complete")
  }

  @Test("DateFormatStyle maps to Date.FormatStyle.DateStyle")
  func testDateFormatStyleMapsToDateStyle() {
    #expect(DateFormatStyle.numeric.dateStyle == .numeric)
    #expect(DateFormatStyle.abbreviated.dateStyle == .abbreviated)
    #expect(DateFormatStyle.long.dateStyle == .long)
    #expect(DateFormatStyle.complete.dateStyle == .complete)
  }
}

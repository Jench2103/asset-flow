//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
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

  // MARK: - Hide Stale Assets

  @Test("hideStaleAssets defaults to true when storage is empty")
  func hideStaleAssets_defaultsToTrueWhenUnset() {
    let service = SettingsService.createForTesting()
    #expect(service.hideStaleAssets == true)
  }

  @Test("hideStaleAssets persists across instances sharing the same storage")
  func hideStaleAssets_persistsAcrossInstances() {
    let suiteName = "com.assetflow.testing.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create UserDefaults suite for testing")
      return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let writer = SettingsService.createForTesting(userDefaults: userDefaults)
    writer.hideStaleAssets = false

    let reader = SettingsService.createForTesting(userDefaults: userDefaults)
    #expect(reader.hideStaleAssets == false)
  }

  // MARK: - Snapshot Reminder

  @Test("Default snapshotReminderEnabled is false")
  func snapshotReminderEnabled_defaultsFalse() {
    let service = SettingsService.createForTesting()
    #expect(service.snapshotReminderEnabled == false)
  }

  @Test("Default snapshotReminderConfig matches SnapshotReminderConfig.default")
  func snapshotReminderConfig_defaultMatches() {
    let service = SettingsService.createForTesting()
    #expect(service.snapshotReminderConfig == SnapshotReminderConfig.default)
  }

  @Test("snapshotReminderEnabled persists across instances sharing storage")
  func snapshotReminderEnabled_persists() {
    let suiteName = "com.assetflow.testing.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create UserDefaults suite for testing")
      return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let writer = SettingsService.createForTesting(userDefaults: userDefaults)
    writer.snapshotReminderEnabled = true

    let reader = SettingsService.createForTesting(userDefaults: userDefaults)
    #expect(reader.snapshotReminderEnabled == true)
  }

  @Test("snapshotReminderConfig round-trips across instances sharing storage")
  func snapshotReminderConfig_persists() {
    let suiteName = "com.assetflow.testing.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create UserDefaults suite for testing")
      return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    let writer = SettingsService.createForTesting(userDefaults: userDefaults)
    let custom = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 5,
      dayOfMonth: 10,
      hour: 14,
      minute: 45,
      intervalDays: 12
    )
    writer.snapshotReminderConfig = custom

    let reader = SettingsService.createForTesting(userDefaults: userDefaults)
    #expect(reader.snapshotReminderConfig == custom)
  }

  @Test("Corrupt snapshotReminderConfig data falls back to default without crashing")
  func snapshotReminderConfig_corruptDataFallsBack() {
    let suiteName = "com.assetflow.testing.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create UserDefaults suite for testing")
      return
    }
    defer { userDefaults.removePersistentDomain(forName: suiteName) }

    userDefaults.set(
      Data([0xFF, 0xFE, 0xFD]),
      forKey: Constants.UserDefaultsKeys.snapshotReminderConfig)

    let service = SettingsService.createForTesting(userDefaults: userDefaults)
    #expect(service.snapshotReminderConfig == SnapshotReminderConfig.default)
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

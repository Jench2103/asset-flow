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
import LocalAuthentication
import Testing
import UserNotifications

@testable import AssetFlow

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {

  // MARK: - Initialization

  @Test("ViewModel initializes with current settings values")
  func testInitializesWithCurrentSettings() {
    let settingsService = SettingsService.createForTesting()
    settingsService.mainCurrency = "EUR"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.selectedCurrency == "EUR")
  }

  // MARK: - Currency Selection

  @Test("Changing selected currency updates settings service immediately")
  func testCurrencyChangeUpdatesSettingsImmediately() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedCurrency = "JPY"
    #expect(settingsService.mainCurrency == "JPY")
  }

  @Test("Available currencies come from CurrencyService")
  func testCurrenciesFromCurrencyService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.availableCurrencies.count == CurrencyService.shared.currencies.count)
    #expect(viewModel.availableCurrencies.contains { $0.code == "USD" })
  }

  @Test("Same currency selection does not update service")
  func testSameCurrencyDoesNotUpdateService() {
    let settingsService = SettingsService.createForTesting()
    settingsService.mainCurrency = "USD"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedCurrency = "USD"
    #expect(settingsService.mainCurrency == "USD")
  }

  // MARK: - Date Format

  @Test("Init loads current dateFormat from service")
  func testInitLoadsDateFormat() {
    let settingsService = SettingsService.createForTesting()
    settingsService.dateFormat = .long
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.selectedDateFormat == .long)
  }

  @Test("Changing dateFormat updates service immediately")
  func testDateFormatChangeUpdatesService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedDateFormat = .complete
    #expect(settingsService.dateFormat == .complete)
  }

  @Test("Same dateFormat doesn't trigger update")
  func testSameDateFormatDoesNotTriggerUpdate() {
    let settingsService = SettingsService.createForTesting()
    settingsService.dateFormat = .abbreviated
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedDateFormat = .abbreviated
    #expect(settingsService.dateFormat == .abbreviated)
  }

  @Test("Available formats is non-empty and at most DateFormatStyle.allCases count")
  func testAvailableFormatsCount() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(!viewModel.availableDateFormats.isEmpty)
    #expect(viewModel.availableDateFormats.count <= DateFormatStyle.allCases.count)
  }

  @Test("availableDateFormats has no duplicate preview strings")
  func testAvailableDateFormatsNoDuplicatePreviews() {
    let viewModel = SettingsViewModel(settingsService: SettingsService.createForTesting())
    let previews = viewModel.availableDateFormats.map { $0.preview(for: Date()) }
    let uniquePreviews = Set(previews)
    #expect(previews.count == uniquePreviews.count)
  }

  // MARK: - Default Platform

  @Test("Init loads current defaultPlatform from service")
  func testInitLoadsDefaultPlatform() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.defaultPlatformString == "Schwab")
  }

  @Test("Changing defaultPlatform updates service immediately")
  func testDefaultPlatformChangeUpdatesService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = "Firstrade"
    #expect(settingsService.defaultPlatform == "Firstrade")
  }

  @Test("Empty defaultPlatform is valid")
  func testEmptyDefaultPlatformIsValid() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = ""
    #expect(settingsService.defaultPlatform == "")
  }

  @Test("Same defaultPlatform doesn't trigger update")
  func testSameDefaultPlatformDoesNotTriggerUpdate() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = "Schwab"
    #expect(settingsService.defaultPlatform == "Schwab")
  }

  // MARK: - App Lock (Authentication)

  /// Mock LAContext for testing biometric availability.
  private class MockLAContext: LAContext {
    var canEvaluateResult = true
    var evaluateResult = true

    override func canEvaluatePolicy(
      _ policy: LAPolicy, error: NSErrorPointer
    ) -> Bool {
      canEvaluateResult
    }

    override func evaluatePolicy(
      _ policy: LAPolicy, localizedReason: String
    ) async throws -> Bool {
      if evaluateResult { return true }
      throw LAError(.userCancel)
    }
  }

  private func createViewModelWithAuth(
    canEvaluate: Bool = true,
    evaluateSuccess: Bool = true
  ) -> (viewModel: SettingsViewModel, authService: AuthenticationService) {
    let mock = MockLAContext()
    mock.canEvaluateResult = canEvaluate
    mock.evaluateResult = evaluateSuccess
    let settingsService = SettingsService.createForTesting()
    let authService = AuthenticationService.createForTesting(
      laContextFactory: { mock }
    )
    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      authenticationService: authService
    )
    return (viewModel, authService)
  }

  @Test("ViewModel initializes isAppLockEnabled from AuthenticationService")
  func testInitLoadsAppLockEnabled() {
    let (viewModel, _) = createViewModelWithAuth()
    #expect(viewModel.isAppLockEnabled == false)
  }

  @Test("ViewModel initializes appSwitchTimeout from AuthenticationService")
  func testInitLoadsAppSwitchTimeout() {
    let (viewModel, _) = createViewModelWithAuth()
    #expect(viewModel.appSwitchTimeout == .immediately)
  }

  @Test("ViewModel initializes screenLockTimeout from AuthenticationService")
  func testInitLoadsScreenLockTimeout() {
    let (viewModel, _) = createViewModelWithAuth()
    #expect(viewModel.screenLockTimeout == .immediately)
  }

  @Test("Changing appSwitchTimeout syncs to AuthenticationService")
  func testAppSwitchTimeoutSyncsToAuthService() {
    let (viewModel, authService) = createViewModelWithAuth()
    viewModel.appSwitchTimeout = .fiveMinutes
    #expect(authService.appSwitchTimeout == .fiveMinutes)
  }

  @Test("Changing screenLockTimeout syncs to AuthenticationService")
  func testScreenLockTimeoutSyncsToAuthService() {
    let (viewModel, authService) = createViewModelWithAuth()
    viewModel.screenLockTimeout = .fifteenMinutes
    #expect(authService.screenLockTimeout == .fifteenMinutes)
  }

  @Test("Setting both timeouts to .never auto-disables isAppLockEnabled")
  func testBothNeverAutoDisablesAppLock() {
    // Pre-enable app lock at the service level, then create ViewModel
    // so it picks up isAppLockEnabled = true at init (avoids async auth Task)
    let mock = MockLAContext()
    mock.canEvaluateResult = true
    mock.evaluateResult = true
    let settingsService = SettingsService.createForTesting()
    let authService = AuthenticationService.createForTesting(
      laContextFactory: { mock }
    )
    authService.isAppLockEnabled = true
    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      authenticationService: authService
    )
    #expect(viewModel.isAppLockEnabled == true)

    viewModel.appSwitchTimeout = .never
    // Only one is .never — should still be enabled
    #expect(viewModel.isAppLockEnabled == true)

    viewModel.screenLockTimeout = .never
    // Both are .never — should auto-disable
    #expect(viewModel.isAppLockEnabled == false)
    #expect(authService.isAppLockEnabled == false)
  }

  @Test("Re-enabling app lock after auto-disable resets timeouts to .immediately")
  func testReEnableAfterAutoDisableResetsTimeouts() async {
    // Pre-enable app lock at the service level so ViewModel picks it up at init
    let mock = MockLAContext()
    mock.canEvaluateResult = true
    mock.evaluateResult = true
    let settingsService = SettingsService.createForTesting()
    let authService = AuthenticationService.createForTesting(
      laContextFactory: { mock }
    )
    authService.isAppLockEnabled = true
    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      authenticationService: authService
    )
    #expect(viewModel.isAppLockEnabled == true)

    // Set both to .never → auto-disables
    viewModel.appSwitchTimeout = .never
    viewModel.screenLockTimeout = .never
    #expect(viewModel.isAppLockEnabled == false)
    #expect(authService.appSwitchTimeout == .never)
    #expect(authService.screenLockTimeout == .never)

    // Re-enable toggle → timeouts should reset to .immediately
    viewModel.isAppLockEnabled = true

    // Wait for the async auth Task to complete
    await viewModel.authTask?.value

    #expect(viewModel.isAppLockEnabled == true)
    #expect(authService.isAppLockEnabled == true)
    #expect(viewModel.appSwitchTimeout == .immediately)
    #expect(viewModel.screenLockTimeout == .immediately)
    #expect(authService.appSwitchTimeout == .immediately)
    #expect(authService.screenLockTimeout == .immediately)
  }

  @Test("canUseBiometrics reflects AuthenticationService.canEvaluatePolicy")
  func testCanUseBiometricsReflectsAuthService() {
    let (viewModel, _) = createViewModelWithAuth(canEvaluate: true)
    #expect(viewModel.canUseBiometrics == true)

    let (viewModel2, _) = createViewModelWithAuth(canEvaluate: false)
    #expect(viewModel2.canUseBiometrics == false)
  }

  // MARK: - Snapshot Reminder

  private func makeReminderHarness(
    storedEnabled: Bool = false,
    storedConfig: SnapshotReminderConfig? = nil,
    authorization: UNAuthorizationStatus = .authorized
  ) -> (
    viewModel: SettingsViewModel,
    settingsService: SettingsService,
    reminderService: SnapshotReminderService,
    center: FakeNotificationCenter
  ) {
    let settingsService = SettingsService.createForTesting()
    settingsService.snapshotReminderEnabled = storedEnabled
    settingsService.snapshotReminderConfig = storedConfig ?? .default
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = authorization
    let reminderService = SnapshotReminderService.createForTesting(center: center)
    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      reminderService: reminderService
    )
    return (viewModel, settingsService, reminderService, center)
  }

  @Test("Reminder bindings initialize from stored config")
  func reminderInitializesFromStoredConfig() {
    let custom = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 3, dayOfMonth: 7, hour: 17, minute: 30, intervalDays: 21)
    let harness = makeReminderHarness(storedEnabled: true, storedConfig: custom)
    #expect(harness.viewModel.isReminderEnabled == true)
    #expect(harness.viewModel.reminderFrequency == .biweekly)
    #expect(harness.viewModel.reminderWeekday == 3)
    #expect(harness.viewModel.reminderDayOfMonth == 7)
    #expect(harness.viewModel.reminderIntervalDays == 21)
    let components = Calendar.current.dateComponents(
      [.hour, .minute], from: harness.viewModel.reminderTime)
    #expect(components.hour == 17)
    #expect(components.minute == 30)
  }

  @Test("Toggling reminder on with .authorized persists and reschedules")
  func reminderToggleOnAuthorized() async {
    let harness = makeReminderHarness(authorization: .authorized)

    harness.viewModel.isReminderEnabled = true
    await harness.viewModel.reminderTask?.value

    #expect(harness.settingsService.snapshotReminderEnabled == true)
    #expect(harness.center.addedRequests.count >= 1)
    #expect(harness.center.requestAuthorizationCallCount == 0)
  }

  @Test("Toggling reminder on with .notDetermined requests authorization, then schedules")
  func reminderToggleOnNotDeterminedThenAuthorized() async {
    let harness = makeReminderHarness(authorization: .notDetermined)
    harness.center.stubbedRequestAuthorizationResult = true

    harness.viewModel.isReminderEnabled = true
    await harness.viewModel.reminderTask?.value

    #expect(harness.center.requestAuthorizationCallCount == 1)
    #expect(harness.settingsService.snapshotReminderEnabled == true)
  }

  @Test("Toggling reminder on with .denied reverts and surfaces alert")
  func reminderToggleOnDenied() async {
    let harness = makeReminderHarness(authorization: .denied)

    harness.viewModel.isReminderEnabled = true
    await harness.viewModel.reminderTask?.value

    #expect(harness.viewModel.isReminderEnabled == false)
    #expect(harness.viewModel.showAuthorizationDeniedAlert == true)
    #expect(harness.settingsService.snapshotReminderEnabled == false)
    #expect(harness.center.addedRequests.isEmpty)
  }

  @Test("Toggling reminder off persists false and cancels schedule")
  func reminderToggleOff() async {
    let harness = makeReminderHarness(
      storedEnabled: true, authorization: .authorized)
    // Pre-load a recurring request so we can observe its removal.
    harness.center.pending = [
      UNNotificationRequest(
        identifier: "snapshotReminder.weekly",
        content: UNNotificationContent(),
        trigger: nil)
    ]

    harness.viewModel.isReminderEnabled = false
    await harness.viewModel.reminderTask?.value

    #expect(harness.settingsService.snapshotReminderEnabled == false)
    #expect(harness.center.addedRequests.isEmpty)
    let removed = Set(harness.center.removedIdentifiers.flatMap { $0 })
    #expect(removed.contains("snapshotReminder.weekly"))
  }

  @Test("Changing frequency while enabled persists and reschedules")
  func reminderFrequencyChangePersistsAndReschedules() async {
    let harness = makeReminderHarness(
      storedEnabled: true, authorization: .authorized)

    harness.viewModel.reminderFrequency = .monthly
    await harness.viewModel.reminderTask?.value

    #expect(harness.settingsService.snapshotReminderConfig.frequency == .monthly)
    #expect(harness.center.addedRequests.count >= 1)
  }

  @Test("Changing reminderIntervalDays while enabled persists and reschedules")
  func reminderIntervalChangePersistsAndReschedules() async {
    let harness = makeReminderHarness(
      storedEnabled: true,
      storedConfig: SnapshotReminderConfig(
        frequency: .interval,
        weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10),
      authorization: .authorized)

    harness.viewModel.reminderIntervalDays = 21
    await harness.viewModel.reminderTask?.value

    #expect(harness.settingsService.snapshotReminderConfig.intervalDays == 21)
    #expect(harness.center.addedRequests.count >= 1)
  }

  @Test("Changing reminderTime extracts hour and minute and persists")
  func reminderTimeExtractsHourMinute() async {
    let harness = makeReminderHarness(
      storedEnabled: true, authorization: .authorized)
    let target =
      Calendar.current.date(
        bySettingHour: 7, minute: 45, second: 0, of: Date()) ?? Date()

    harness.viewModel.reminderTime = target
    await harness.viewModel.reminderTask?.value

    #expect(harness.settingsService.snapshotReminderConfig.hour == 7)
    #expect(harness.settingsService.snapshotReminderConfig.minute == 45)
  }

  @Test("Disabling app lock syncs to AuthenticationService and unlocks")
  func testDisableAppLockUnlocks() {
    let mock = MockLAContext()
    mock.canEvaluateResult = true
    mock.evaluateResult = true
    let settingsService = SettingsService.createForTesting()
    let authService = AuthenticationService.createForTesting(
      laContextFactory: { mock }
    )
    // Pre-enable app lock at the service level
    authService.isAppLockEnabled = true
    authService.lockOnLaunchIfNeeded()
    #expect(authService.isLocked == true)

    // Create ViewModel — it reads isAppLockEnabled = true from authService
    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      authenticationService: authService
    )
    #expect(viewModel.isAppLockEnabled == true)

    // Disable via ViewModel
    viewModel.isAppLockEnabled = false
    #expect(authService.isAppLockEnabled == false)
    #expect(authService.isLocked == false)
  }
}

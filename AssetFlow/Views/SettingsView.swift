//
//  SettingsView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import SwiftUI

/// Settings View - App-wide settings configuration
///
/// Allows users to configure:
/// - Main currency for displaying portfolio values
/// - Financial goal (target wealth amount)
///
/// All settings auto-save when input is valid:
/// - Currency: Saves immediately on change
/// - Financial goal: Saves after 0.75s debounce, or immediately on Enter/focus loss
struct SettingsView: View {
  @State private var viewModel: SettingsViewModel
  @FocusState private var isGoalFieldFocused: Bool

  init(settingsService: SettingsService? = nil) {
    _viewModel = State(wrappedValue: SettingsViewModel(settingsService: settingsService))
  }

  var body: some View {
    Form {
      // Currency Section
      currencySection

      // Financial Goal Section
      financialGoalSection
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
  }

  // MARK: - Currency Section

  private var currencySection: some View {
    Section {
      Picker("Main Currency", selection: $viewModel.selectedCurrency) {
        ForEach(viewModel.availableCurrencies) { currency in
          Text(currency.displayName)
            .tag(currency.code)
        }
      }
      .accessibilityIdentifier("Main Currency Picker")
    } header: {
      Text("Display Currency")
    } footer: {
      Text("The currency used to display total portfolio values across the app.")
    }
  }

  // MARK: - Financial Goal Section

  private var financialGoalSection: some View {
    Section {
      HStack {
        TextField("Target amount", text: $viewModel.goalAmountString)
          .textFieldStyle(.roundedBorder)
          .focused($isGoalFieldFocused)
          .onSubmit { viewModel.commitGoal() }
          .onChange(of: isGoalFieldFocused) { _, isFocused in
            if !isFocused { viewModel.onFocusLost() }
          }
          .accessibilityIdentifier("Financial Goal Input")
          #if os(macOS)
            .frame(maxWidth: 200)
          #endif

        if !viewModel.goalAmountString.isEmpty {
          Button {
            viewModel.clearGoal()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("Clear Goal Button")
        }

        // Saved indicator
        if viewModel.showSavedIndicator {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            Text("Saved")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .transition(.opacity.combined(with: .scale))
          .accessibilityIdentifier("Saved Indicator")
        }
      }
      .animation(.easeInOut(duration: 0.2), value: viewModel.showSavedIndicator)
      .animation(.easeInOut(duration: 0.2), value: viewModel.conversionMessage)

      // Validation message
      if let message = viewModel.goalValidationMessage {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text(message)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }

      // Conversion message
      if let conversionMsg = viewModel.conversionMessage {
        HStack {
          Image(systemName: "arrow.triangle.2.circlepath")
            .foregroundStyle(.blue)
          Text(conversionMsg)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .transition(.opacity)
        .accessibilityIdentifier("Conversion Message")
      }
    } header: {
      Text("Financial Goal")
    } footer: {
      Text(
        """
        Set a target wealth amount. Your progress towards this goal will be shown \
        on the Overview page.
        """
      )
    }
  }
}

// MARK: - Previews

#Preview("Settings View") {
  NavigationStack {
    SettingsView(settingsService: SettingsService.createForTesting())
  }
}

#Preview("Settings with Goal") {
  let service = SettingsService.createForTesting()
  service.mainCurrency = "EUR"
  service.financialGoal = Decimal(1_000_000)

  return NavigationStack {
    SettingsView(settingsService: service)
  }
}

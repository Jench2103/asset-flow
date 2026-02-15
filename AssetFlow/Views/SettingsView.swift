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
///
/// Currency saves immediately on change.
struct SettingsView: View {
  @State private var viewModel: SettingsViewModel

  init(settingsService: SettingsService? = nil) {
    _viewModel = State(wrappedValue: SettingsViewModel(settingsService: settingsService))
  }

  var body: some View {
    Form {
      currencySection
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
}

// MARK: - Previews

#Preview("Settings View") {
  NavigationStack {
    SettingsView(settingsService: SettingsService.createForTesting())
  }
}

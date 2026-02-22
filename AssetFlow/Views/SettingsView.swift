//
//  SettingsView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings View - App-wide settings configuration
///
/// Allows users to configure:
/// - Main currency for displaying portfolio values
/// - Date display format
/// - Default platform for imports
/// - Data management (backup/restore)
///
/// All settings save immediately on change.
struct SettingsView: View {
  @State private var viewModel: SettingsViewModel
  @Environment(\.modelContext) private var modelContext

  @State private var showRestoreConfirmation = false
  @State private var showResultAlert = false
  @State private var resultMessage = ""
  @State private var isError = false
  @State private var pendingRestoreURL: URL?

  private let settingsService: SettingsService

  init(settingsService: SettingsService? = nil) {
    let resolved = settingsService ?? SettingsService.shared
    self.settingsService = resolved
    _viewModel = State(wrappedValue: SettingsViewModel(settingsService: resolved))
  }

  var body: some View {
    Form {
      currencySection
      dateFormatSection
      importDefaultsSection
      dataManagementSection
      aboutSection
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
    .task {
      await CurrencyService.shared.loadFromAPI()
    }
    .alert(
      isError ? "Error" : "Success",
      isPresented: $showResultAlert
    ) {
      Button("OK") {}
    } message: {
      Text(resultMessage)
    }
    .confirmationDialog(
      "Restore from Backup",
      isPresented: $showRestoreConfirmation
    ) {
      Button("Restore", role: .destructive) {
        performRestore()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Restoring from backup will replace ALL existing data. This cannot be undone. Continue?"
      )
    }
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

  // MARK: - Date Format Section

  private var dateFormatSection: some View {
    Section {
      Picker("Date Format", selection: $viewModel.selectedDateFormat) {
        ForEach(viewModel.availableDateFormats, id: \.self) { format in
          Text(format.preview(for: Date()))
            .tag(format)
        }
      }
      .accessibilityIdentifier("Date Format Picker")
    } header: {
      Text("Date Format")
    } footer: {
      Text("How dates are displayed throughout the app.")
    }
  }

  // MARK: - Import Defaults Section

  private var importDefaultsSection: some View {
    Section {
      TextField("Default Platform", text: $viewModel.defaultPlatformString)
        .accessibilityIdentifier("Default Platform Field")
    } header: {
      Text("Import Defaults")
    } footer: {
      Text("Pre-fills the platform field when importing CSV files. Leave empty for no default.")
    }
  }

  // MARK: - Data Management Section

  private var dataManagementSection: some View {
    Section {
      Button("Export Backup...") {
        performExport()
      }
      .help("Export all data as a ZIP archive")
      .accessibilityIdentifier("Export Backup Button")

      Button("Restore from Backup...") {
        openRestorePanel()
      }
      .help("Restore data from a previous backup")
      .accessibilityIdentifier("Restore Backup Button")
    } header: {
      Text("Data Management")
    } footer: {
      Text("Export all data as a ZIP archive or restore from a previous backup.")
    }
  }

  // MARK: - About Section

  private var aboutSection: some View {
    Section {
      HStack(alignment: .top, spacing: 12) {
        if let appIcon = NSApplication.shared.applicationIconImage {
          Image(nsImage: appIcon)
            .resizable()
            .frame(width: 48, height: 48)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(Constants.AppInfo.name)
            .font(.headline)
          Text("Version \(Constants.AppInfo.version) (\(Constants.AppInfo.buildNumber))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      LabeledContent("Developer", value: Constants.AppInfo.developerName)
      LabeledContent("License", value: Constants.AppInfo.license)
      LabeledContent("Privacy") {
        Text(
          "All data is stored locally. Exchange rates are fetched from cdn.jsdelivr.net. No personal data is collected or transmitted."
        )
      }
      Link("View Source Code on GitHub", destination: Constants.AppInfo.repositoryURL)
    } header: {
      Text("About")
    }
  }

  // MARK: - Backup Actions

  @MainActor
  private func performExport() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.zip]
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    panel.nameFieldStringValue =
      "AssetFlow-Backup-\(dateFormatter.string(from: Date())).zip"

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      try BackupService.exportBackup(
        to: url, modelContext: modelContext,
        settingsService: settingsService)
      resultMessage = String(
        localized: "Backup exported successfully.", table: "Settings")
      isError = false
      showResultAlert = true
    } catch {
      resultMessage = error.localizedDescription
      isError = true
      showResultAlert = true
    }
  }

  @MainActor
  private func openRestorePanel() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.zip]
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let url = panel.url else { return }

    pendingRestoreURL = url
    showRestoreConfirmation = true
  }

  @MainActor
  private func performRestore() {
    guard let url = pendingRestoreURL else { return }
    pendingRestoreURL = nil

    do {
      try BackupService.restoreFromBackup(
        at: url, modelContext: modelContext,
        settingsService: settingsService)
      // Sync ViewModel with restored settings
      viewModel = SettingsViewModel(settingsService: settingsService)
      resultMessage = String(
        localized: "Backup restored successfully.", table: "Settings")
      isError = false
      showResultAlert = true
    } catch {
      resultMessage = error.localizedDescription
      isError = true
      showResultAlert = true
    }
  }
}

// MARK: - Previews

#Preview("Settings View") {
  NavigationStack {
    SettingsView(settingsService: SettingsService.createForTesting())
  }
}

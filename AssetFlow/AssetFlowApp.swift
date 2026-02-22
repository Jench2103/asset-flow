//
//  AssetFlowApp.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import AppKit
import SwiftData
import SwiftUI

@main
struct AssetFlowApp: App {
  let sharedModelContainer: ModelContainer

  init() {
    let schema = Schema(versionedSchema: SchemaV1.self)
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      sharedModelContainer = try ModelContainer(
        for: schema,
        migrationPlan: AssetFlowMigrationPlan.self,
        configurations: [modelConfiguration]
      )
    } catch {
      Self.showDatabaseErrorAndExit(error)
    }
  }

  /// Shows a modal alert about the database error and terminates the app after dismissal.
  private static func showDatabaseErrorAndExit(_ error: Error) -> Never {
    let alert = NSAlert()
    alert.messageText = String(
      localized: "Unable to Open Database",
      table: "Services"
    )
    alert.informativeText = String(
      localized: """
        AssetFlow could not open its database due to an incompatible schema. \
        Your data has not been deleted.

        Please file an issue at the GitHub repository so we can help resolve this.

        Error: \(error.localizedDescription)
        """,
      table: "Services"
    )
    alert.alertStyle = .critical
    alert.addButton(withTitle: String(localized: "Open GitHub Issues", table: "Services"))
    alert.addButton(withTitle: String(localized: "Quit", table: "Services"))

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      let issuesURL = Constants.AppInfo.repositoryURL.appending(path: "issues")
      NSWorkspace.shared.open(issuesURL)
    }

    NSApp.terminate(nil)
    fatalError("Could not create ModelContainer: \(error)")
  }

  @FocusedValue(\.newSnapshotAction) private var newSnapshotAction
  @FocusedValue(\.importCSVAction) private var importCSVAction

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
    .windowStyle(.hiddenTitleBar)
    .windowToolbarStyle(.unified)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Snapshot...") {
          newSnapshotAction?()
        }
        .keyboardShortcut("n")
        .disabled(newSnapshotAction == nil)

        Divider()

        Button("Import CSV...") {
          importCSVAction?()
        }
        .keyboardShortcut("i")
        .disabled(importCSVAction == nil)
      }
      CommandGroup(replacing: .appInfo) {
        Button("About AssetFlow") {
          let body = NSFont.systemFont(ofSize: NSFont.systemFontSize)
          let small = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
          let center = NSMutableParagraphStyle()
          center.alignment = .center

          let credits = NSMutableAttributedString()

          // License
          credits.append(
            NSAttributedString(
              string: "\(Constants.AppInfo.license)\n",
              attributes: [.font: body, .paragraphStyle: center]
            ))

          // Source code link
          credits.append(
            NSAttributedString(
              string: "View Source Code on GitHub",
              attributes: [
                .font: body,
                .link: Constants.AppInfo.repositoryURL,
                .paragraphStyle: center,
              ]
            ))

          // Privacy statement — small, secondary
          credits.append(
            NSAttributedString(
              string:
                "\n\nAll data is stored locally on your Mac.\nExchange rates are fetched from cdn.jsdelivr.net.\nNo personal data is collected or transmitted.",
              attributes: [
                .font: small,
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: center,
              ]
            ))

          NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "AssetFlow",
            .applicationIcon: NSApp.applicationIconImage as Any,
            .credits: credits,
          ])
        }
      }
    }

    Settings {
      SettingsView()
    }
    .modelContainer(sharedModelContainer)
  }
}

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

  private let authService = AuthenticationService.shared

  var body: some Scene {
    WindowGroup {
      ZStack {
        ContentView()
        if authService.isLocked {
          LockScreenView(authService: authService)
            .transition(.opacity)
        }
      }
      .environment(\.isAppLocked, authService.isLocked)
      .onAppear {
        authService.lockOnLaunchIfNeeded()
      }
      // ── App Activation Lifecycle ──
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in
        authService.isAppActive = false
        authService.recordBackground(trigger: .appSwitch)
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in
        authService.isAppActive = true
        authService.evaluateOnBecomeActive()
      }
      // ── Screen Lock / Sleep ──
      .onReceive(
        NSWorkspace.shared.notificationCenter.publisher(
          for: NSWorkspace.screensDidSleepNotification)
      ) { _ in
        authService.recordBackground(trigger: .screenSleep)
      }
      .onReceive(
        DistributedNotificationCenter.default().publisher(
          for: Notification.Name("com.apple.screenIsLocked"))
      ) { _ in
        authService.recordBackground(trigger: .screenSleep)
      }
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
        .disabled(newSnapshotAction == nil || authService.isLocked)

        Divider()

        Button("Import CSV...") {
          importCSVAction?()
        }
        .keyboardShortcut("i")
        .disabled(importCSVAction == nil || authService.isLocked)
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
              string: String(localized: "View Source Code on GitHub"),
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
                "\n\n"
                + String(
                  localized:
                    "All data is stored locally on your Mac.\nExchange rates are fetched from cdn.jsdelivr.net.\nNo personal data is collected or transmitted."
                ),
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
      ZStack {
        SettingsView()
        if authService.isLocked {
          LockScreenView(authService: authService)
            .transition(.opacity)
        }
      }
      .environment(\.isAppLocked, authService.isLocked)
    }
    .modelContainer(sharedModelContainer)
  }
}

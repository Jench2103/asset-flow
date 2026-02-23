//
//  LockScreenView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/23.
//

import SwiftUI

/// Full-window opaque overlay displayed when the app is locked.
///
/// Uses the system `LAContext.evaluatePolicy` dialog for authentication —
/// no custom biometric UI (Apple HIG compliant).
struct LockScreenView: View {
  let authService: AuthenticationService

  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 20) {
      if let appIcon = NSApplication.shared.applicationIconImage {
        Image(nsImage: appIcon)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 128, height: 128)
      }

      Text("AssetFlow is Locked")
        .font(.title)
        .fontWeight(.semibold)

      Button("Unlock") {
        Task { await unlock() }
      }
      .keyboardShortcut(.defaultAction)
      .controlSize(.large)
      .disabled(authService.isAuthenticating)

      if let errorMessage {
        Text(errorMessage)
          .foregroundStyle(.secondary)
          .font(.callout)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial)
    .task(id: authService.isLocked) {
      // Auto-auth on view appear, but only if app is active (e.g., lock on launch).
      // When locked eagerly in background, this returns false and does nothing.
      guard authService.isLocked else { return }
      try? await Task.sleep(for: .milliseconds(200))
      guard !Task.isCancelled else { return }
      await autoUnlockIfActive()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
    ) { _ in
      // When user returns to a locked app, auto-trigger auth.
      // This is the PRIMARY deferred auth mechanism.
      guard authService.isLocked, !authService.isAuthenticating else { return }
      Task {
        try? await Task.sleep(for: .milliseconds(300))
        await autoUnlockIfActive()
      }
    }
  }

  /// Auto-attempts authentication only if the app is active.
  /// No error message for auto-attempts — user didn't explicitly request unlock.
  private func autoUnlockIfActive() async {
    guard authService.isLocked, !authService.isAuthenticating else { return }
    _ = await authService.authenticateIfActive()
  }

  /// Manual unlock triggered by the "Unlock" button. Shows error on failure.
  private func unlock() async {
    errorMessage = nil
    let success = await authService.authenticate()
    if !success {
      errorMessage = String(
        localized: "Authentication failed. Try again.",
        table: "Settings"
      )
    }
  }
}

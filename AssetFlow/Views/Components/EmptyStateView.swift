//
//  EmptyStateView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftUI

/// A reusable empty state component for screens with no data.
///
/// Displays a centered layout with an SF Symbol icon, title, descriptive message,
/// and optional action buttons. Used across all list and dashboard views to provide
/// consistent empty state messaging per SPEC 3.9.
struct EmptyStateView: View {
  let icon: String
  let title: String
  let message: String
  var actions: [EmptyStateAction] = []

  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: icon)
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(title)
        .font(.title2)

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      if !actions.isEmpty {
        HStack(spacing: 12) {
          ForEach(actions) { action in
            if action.isPrimary {
              Button(action.label) {
                action.action()
              }
              .buttonStyle(.borderedProminent)
            } else {
              Button(action.label) {
                action.action()
              }
            }
          }
        }
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// An action button displayed in an empty state view.
struct EmptyStateAction: Identifiable {
  var id: String { label }
  let label: String
  let isPrimary: Bool
  let action: () -> Void
}

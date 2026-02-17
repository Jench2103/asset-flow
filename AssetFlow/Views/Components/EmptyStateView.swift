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
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: icon)
        .font(.system(size: 48, weight: .light))
        .foregroundStyle(.secondary)
        .frame(width: 80, height: 80)
        .background(.fill.quaternary)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text(title)
          .font(.title2)

        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 400)
          .padding(.horizontal)
      }

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
        .padding(.top, 4)
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

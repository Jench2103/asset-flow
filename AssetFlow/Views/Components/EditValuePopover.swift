//
//  EditValuePopover.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/23.
//

import SwiftUI

/// A popover for editing a decimal market value.
///
/// Displays a text field pre-populated with the current value and
/// Save/Cancel buttons. Used by both `SnapshotDetailView` and
/// `AssetDetailView` for inline value editing.
struct EditValuePopover: View {
  let currentValue: Decimal
  let onSave: (Decimal) -> Void
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isValueFocused: Bool
  @State private var valueText: String

  init(currentValue: Decimal, onSave: @escaping (Decimal) -> Void) {
    self.currentValue = currentValue
    self.onSave = onSave
    _valueText = State(wrappedValue: NSDecimalNumber(decimal: currentValue).stringValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Market Value").font(.headline)
      TextField("Market Value", text: $valueText)
        .textFieldStyle(.roundedBorder)
        .focused($isValueFocused)
        .onSubmit { saveIfValid() }
        .accessibilityIdentifier("Edit Market Value Field")
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save") { saveIfValid() }
          .keyboardShortcut(.defaultAction)
          .disabled(Decimal(string: valueText) == nil)
      }
    }
    .frame(width: 280)
    .padding()
    .onAppear { isValueFocused = true }
  }

  private func saveIfValid() {
    guard let newValue = Decimal(string: valueText) else { return }
    onSave(newValue)
    dismiss()
  }
}

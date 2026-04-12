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
          .disabled(Decimal.parse(valueText) == nil)
      }
    }
    .frame(width: 280)
    .padding()
    .onAppear { isValueFocused = true }
  }

  private func saveIfValid() {
    guard let newValue = Decimal.parse(valueText) else { return }
    onSave(newValue)
    dismiss()
  }
}

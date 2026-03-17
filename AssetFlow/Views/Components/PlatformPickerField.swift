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

/// A reusable picker for selecting or creating a platform.
///
/// Shows a picker with existing platforms, a "None" option, and a "New Platform..."
/// option that toggles to a text field for entering a new platform name.
/// Commit logic performs case-insensitive deduplication against the cached list.
struct PlatformPickerField: View {
  @Binding var selectedPlatform: String
  @Binding var cachedPlatforms: [String]
  var onCommit: (() -> Void)?

  @State private var showNewField = false
  @State private var newName = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showNewField {
        HStack {
          TextField("New platform name", text: $newName)
            .textFieldStyle(.roundedBorder)
            .onSubmit { commitNew() }
          Button("OK") { commitNew() }
          Button("Cancel") {
            showNewField = false
            newName = ""
          }
        }
        .transition(.opacity)
      } else {
        Picker("Platform", selection: pickerBinding) {
          Text("None").tag("")
          ForEach(cachedPlatforms, id: \.self) { platform in
            Text(platform).tag(platform)
          }
          Divider()
          Text("New Platform...").tag("__new__")
        }
        .transition(.opacity)
      }
    }
    .animation(AnimationConstants.standard, value: showNewField)
  }

  private var pickerBinding: Binding<String> {
    Binding(
      get: { selectedPlatform },
      set: { newValue in
        if newValue == "__new__" {
          showNewField = true
          newName = ""
        } else {
          selectedPlatform = newValue
          onCommit?()
        }
      }
    )
  }

  private func commitNew() {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    if let match = cachedPlatforms.first(where: { $0.lowercased() == trimmed.lowercased() }) {
      selectedPlatform = match
    } else {
      selectedPlatform = trimmed
      if !cachedPlatforms.contains(trimmed) {
        cachedPlatforms.append(trimmed)
        cachedPlatforms.sort()
      }
    }

    showNewField = false
    newName = ""
    onCommit?()
  }
}

//
//  PlatformPickerField.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
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

//
//  CategoryPickerField.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/28.
//

import SwiftUI

/// A reusable picker for selecting or creating a category.
///
/// Shows a picker with existing categories, a "None" option, and a "New Category..."
/// option that toggles to a text field for entering a new category name.
/// Uses a `resolveCategory` closure to perform case-insensitive matching or creation.
struct CategoryPickerField: View {
  @Binding var selectedCategory: Category?
  @Binding var cachedCategories: [Category]
  var resolveCategory: (String) -> Category?
  var onCommit: (() -> Void)?

  @State private var showNewField = false
  @State private var newName = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showNewField {
        HStack {
          TextField("New category name", text: $newName)
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
        Picker("Category", selection: pickerBinding) {
          Text("None").tag("")
          ForEach(cachedCategories) { category in
            Text(category.name).tag(category.id.uuidString)
          }
          Divider()
          Text("New Category...").tag("__new__")
        }
        .transition(.opacity)
      }
    }
    .animation(AnimationConstants.standard, value: showNewField)
  }

  private var pickerBinding: Binding<String> {
    Binding(
      get: { selectedCategory?.id.uuidString ?? "" },
      set: { newValue in
        if newValue == "__new__" {
          showNewField = true
          newName = ""
        } else if newValue.isEmpty {
          selectedCategory = nil
          onCommit?()
        } else {
          selectedCategory = cachedCategories.first { $0.id.uuidString == newValue }
          onCommit?()
        }
      }
    )
  }

  private func commitNew() {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    let resolved = resolveCategory(trimmed)
    selectedCategory = resolved

    // Refresh cache if a new category was created
    if let resolved, !cachedCategories.contains(where: { $0.id == resolved.id }) {
      cachedCategories.append(resolved)
      cachedCategories.sort { ($0.displayOrder, $0.name) < ($1.displayOrder, $1.name) }
    }

    showNewField = false
    newName = ""
    onCommit?()
  }
}

//
//  AssetFlowApp.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import SwiftData
import SwiftUI

@main
struct AssetFlowApp: App {
  let sharedModelContainer: ModelContainer

  init() {
    let schema = Schema([
      Category.self,
      Asset.self,
      Snapshot.self,
      SnapshotAssetValue.self,
      CashFlowOperation.self,
    ])

    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      // If the existing store is incompatible (e.g., schema changed without migration),
      // destroy and recreate it. This is acceptable during development.
      Self.destroyExistingStore()
      do {
        sharedModelContainer = try ModelContainer(
          for: schema, configurations: [modelConfiguration])
      } catch {
        fatalError("Could not create ModelContainer: \(error)")
      }
    }
  }

  /// Removes the existing SwiftData store files to allow a fresh start.
  private static func destroyExistingStore() {
    let url = URL.applicationSupportDirectory
      .appending(path: "default.store")
    let fileManager = FileManager.default
    for suffix in ["", "-wal", "-shm"] {
      let fileURL = url.deletingLastPathComponent().appending(
        path: url.lastPathComponent + suffix)
      try? fileManager.removeItem(at: fileURL)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}

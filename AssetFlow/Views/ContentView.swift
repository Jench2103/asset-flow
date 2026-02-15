//
//  ContentView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftUI

/// Stub content view — will be replaced with full sidebar navigation in a later iteration.
struct ContentView: View {
  var body: some View {
    NavigationSplitView {
      List {
        Label("Dashboard", systemImage: "chart.bar")
      }
      .navigationTitle("AssetFlow")
    } detail: {
      Text("AssetFlow")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
    }
    .frame(minWidth: 900, minHeight: 600)
  }
}

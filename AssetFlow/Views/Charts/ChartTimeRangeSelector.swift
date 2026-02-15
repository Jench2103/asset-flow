//
//  ChartTimeRangeSelector.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftUI

/// Reusable segmented picker for chart time range selection (SPEC 12).
///
/// Displays all `ChartTimeRange` cases (1W/1M/3M/6M/1Y/3Y/5Y/All)
/// as a segmented control.
struct ChartTimeRangeSelector: View {
  @Binding var selection: ChartTimeRange

  var body: some View {
    Picker("Time Range", selection: $selection) {
      ForEach(ChartTimeRange.allCases) { range in
        Text(range.rawValue).tag(range)
      }
    }
    .pickerStyle(.segmented)
  }
}

//
//  DateFormattingTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/16.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("Date Settings Formatting Tests")
@MainActor
struct DateFormattingTests {

  @Test("settingsFormatted uses the date format from SettingsService")
  func testSettingsFormattedUsesServiceFormat() {
    let service = SettingsService.createForTesting()
    let date = Date()
    for format in DateFormatStyle.allCases {
      service.dateFormat = format
      let expected = date.formatted(date: format.dateStyle, time: .omitted)
      #expect(date.settingsFormatted(using: service) == expected)
    }
  }
}

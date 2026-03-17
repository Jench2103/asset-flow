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

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

@Suite("SnapshotReminderConfig Tests")
@MainActor
struct SnapshotReminderConfigTests {

  // MARK: - Default

  @Test("Default config is weekly Sunday at 09:00 with intervalDays 10")
  func defaultConfig() {
    let config = SnapshotReminderConfig.default
    #expect(config.frequency == .weekly)
    #expect(config.weekday == 1)
    #expect(config.dayOfMonth == 1)
    #expect(config.hour == 9)
    #expect(config.minute == 0)
    #expect(config.intervalDays == 10)
  }

  // MARK: - JSON round-trip

  @Test(
    "JSON round-trip preserves all fields for every Frequency",
    arguments: SnapshotReminderConfig.Frequency.allCases
  )
  func roundTripPerFrequency(_ frequency: SnapshotReminderConfig.Frequency) throws {
    let original = SnapshotReminderConfig(
      frequency: frequency,
      weekday: 4,
      dayOfMonth: 17,
      hour: 14,
      minute: 23,
      intervalDays: 10
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SnapshotReminderConfig.self, from: data)
    #expect(decoded == original)
  }

  // MARK: - Frequency cases

  @Test("Frequency exposes exactly five cases with stable raw values")
  func frequencyCases() {
    let allCases = SnapshotReminderConfig.Frequency.allCases
    #expect(allCases.count == 5)
    #expect(SnapshotReminderConfig.Frequency.daily.rawValue == "daily")
    #expect(SnapshotReminderConfig.Frequency.weekly.rawValue == "weekly")
    #expect(SnapshotReminderConfig.Frequency.biweekly.rawValue == "biweekly")
    #expect(SnapshotReminderConfig.Frequency.monthly.rawValue == "monthly")
    #expect(SnapshotReminderConfig.Frequency.interval.rawValue == "interval")
  }

  // MARK: - Backward-compatible decode

  @Test("Decoding legacy JSON without intervalDays falls back to a sensible default")
  func decodeLegacyJSON() throws {
    let legacy =
      #"{"frequency":"weekly","weekday":1,"dayOfMonth":1,"hour":9,"minute":0}"#
    let data = legacy.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(SnapshotReminderConfig.self, from: data)
    #expect(decoded.frequency == .weekly)
    #expect(decoded.intervalDays >= 2)
  }

  // MARK: - Decode error

  @Test("Decoding malformed JSON throws a DecodingError")
  func decodeMalformedJSON() {
    let bad = Data([0xFF, 0xFE, 0xFD])
    #expect(throws: (any Error).self) {
      _ = try JSONDecoder().decode(SnapshotReminderConfig.self, from: bad)
    }
  }

  // MARK: - Localized names

  @Test("Each Frequency case exposes a non-empty localized name")
  func localizedNamesNonEmpty() {
    for frequency in SnapshotReminderConfig.Frequency.allCases {
      #expect(!frequency.localizedName.isEmpty)
    }
  }
}

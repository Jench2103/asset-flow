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

/// User-configurable cadence for snapshot reminder notifications.
///
/// Persisted as a JSON-encoded `Data` blob in `UserDefaults` via `SettingsService`.
/// Weekday follows the Calendar convention (Sunday = 1). `dayOfMonth` is capped
/// at 1...28 in the Settings UI for consistent behavior across all months.
/// `intervalDays` is used only by `.interval` frequency.
struct SnapshotReminderConfig: Codable, Equatable, Sendable {
  enum Frequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case biweekly
    case monthly
    case interval
  }

  var frequency: Frequency
  var weekday: Int
  var dayOfMonth: Int
  var hour: Int
  var minute: Int
  /// Repetition stride in days for the `.interval` frequency. Ignored otherwise.
  var intervalDays: Int

  static let `default` = SnapshotReminderConfig(
    frequency: .weekly,
    weekday: 1,
    dayOfMonth: 1,
    hour: 9,
    minute: 0,
    intervalDays: 10
  )

  /// Allowed range for `intervalDays` when `.frequency == .interval`. The
  /// Settings UI's `Stepper` and clamping `Binding` both pull from here so
  /// the bound only needs updating in one place.
  static let intervalDaysRange: ClosedRange<Int> = 2...365

  // Backward-compatible decoding: legacy blobs predate `intervalDays`, so fall
  // back to the default rather than throwing.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.frequency = try container.decode(Frequency.self, forKey: .frequency)
    self.weekday = try container.decode(Int.self, forKey: .weekday)
    self.dayOfMonth = try container.decode(Int.self, forKey: .dayOfMonth)
    self.hour = try container.decode(Int.self, forKey: .hour)
    self.minute = try container.decode(Int.self, forKey: .minute)
    self.intervalDays =
      (try? container.decode(Int.self, forKey: .intervalDays))
      ?? SnapshotReminderConfig.default.intervalDays
  }

  /// Memberwise init with sensible defaults so callers (especially tests)
  /// only need to specify the fields the cadence actually consumes — e.g.
  /// `SnapshotReminderConfig(frequency: .daily, hour: 9, minute: 30)` rather
  /// than passing irrelevant values for `weekday`, `dayOfMonth`, etc.
  init(
    frequency: Frequency = .weekly,
    weekday: Int = 1,
    dayOfMonth: Int = 1,
    hour: Int = 9,
    minute: Int = 0,
    intervalDays: Int = 10
  ) {
    self.frequency = frequency
    self.weekday = weekday
    self.dayOfMonth = dayOfMonth
    self.hour = hour
    self.minute = minute
    self.intervalDays = intervalDays
  }
}

extension SnapshotReminderConfig.Frequency {
  var localizedName: String {
    switch self {
    case .daily:
      return String(localized: "Daily", table: "Settings")

    case .weekly:
      return String(localized: "Weekly", table: "Settings")

    case .biweekly:
      return String(localized: "Every 2 Weeks", table: "Settings")

    case .monthly:
      return String(localized: "Monthly", table: "Settings")

    case .interval:
      return String(localized: "Custom Interval", table: "Settings")
    }
  }
}

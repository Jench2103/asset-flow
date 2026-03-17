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
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Navigation Integration Tests")
@MainActor
struct NavigationIntegrationTests {

  // MARK: - Date-Based Snapshot Lookup Tests (T3)

  @Test("Snapshot can be looked up by date from model context")
  func snapshotLookupByDate() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let date1 = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let date3 = Calendar.current.startOfDay(for: Date())

    let snap1 = Snapshot(date: Calendar.current.startOfDay(for: date1))
    let snap2 = Snapshot(date: Calendar.current.startOfDay(for: date2))
    let snap3 = Snapshot(date: date3)
    context.insert(snap1)
    context.insert(snap2)
    context.insert(snap3)

    let targetDate = Calendar.current.startOfDay(for: date2)
    let descriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? context.fetch(descriptor)) ?? []
    let match = allSnapshots.first(where: {
      Calendar.current.isDate($0.date, inSameDayAs: targetDate)
    })

    #expect(match != nil)
    #expect(match?.id == snap2.id)
  }

  // MARK: - Error Message Tests

  @Test("SnapshotError dateAlreadyExists has correct SPEC 8.1 message format")
  func dateAlreadyExistsErrorMessage() {
    let testDate = Calendar.current.startOfDay(for: Date())
    let error = SnapshotError.dateAlreadyExists(testDate)
    let message = error.errorDescription ?? ""

    // Non-tautological: verify date interpolation and non-empty message
    let formatted = testDate.settingsFormatted()
    #expect(!message.isEmpty)
    #expect(message.contains(formatted))
  }
}

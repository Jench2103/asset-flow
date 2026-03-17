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

@Suite("Category Uniqueness Constraints")
@MainActor
struct CategoryUniquenessTests {

  @Test("Category enforces unique name constraint at database level — duplicate upserts")
  func categoryEnforcesDatabaseUniqueness() throws {
    // Setup in-memory container
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create first category
    let category1 = Category(name: "Equities", targetAllocationPercentage: nil)
    context.insert(category1)
    try context.save()

    // Attempt to create duplicate category (exact same name)
    let category2 = Category(name: "Equities", targetAllocationPercentage: Decimal(50))
    context.insert(category2)
    try context.save()

    // With #Unique constraint, should only have 1 category (upsert behavior)
    let descriptor = FetchDescriptor<AssetFlow.Category>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
  }
}

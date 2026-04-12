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

@Suite("Decimal Parsing Tests")
@MainActor
struct DecimalParsingTests {

  // MARK: - Plain integers

  @Test("Parses plain integers")
  func testPlainInteger() {
    #expect(Decimal.parse("1000") == Decimal(1000))
    #expect(Decimal.parse("0") == Decimal(0))
    #expect(Decimal.parse("123456789") == Decimal(123_456_789))
  }

  // MARK: - US locale (comma = thousands, period = decimal)

  @Test("Parses US-formatted numbers with comma thousands separator")
  func testUSThousandsSeparator() {
    let usLocale = Locale(identifier: "en_US")
    #expect(Decimal.parse("1,000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("1,234,567", locale: usLocale) == Decimal(1_234_567))
  }

  @Test("Parses US-formatted numbers with decimal point")
  func testUSDecimalPoint() {
    let usLocale = Locale(identifier: "en_US")
    #expect(Decimal.parse("1,000.50", locale: usLocale) == Decimal(string: "1000.50"))
    #expect(Decimal.parse("1,234,567.89", locale: usLocale) == Decimal(string: "1234567.89"))
  }

  // MARK: - German locale (period = thousands, comma = decimal)

  @Test("Parses German-formatted numbers with period thousands separator")
  func testGermanThousandsSeparator() {
    let deLocale = Locale(identifier: "de_DE")
    #expect(Decimal.parse("1.000", locale: deLocale) == Decimal(1000))
    #expect(Decimal.parse("1.234.567", locale: deLocale) == Decimal(1_234_567))
  }

  @Test("Parses German-formatted numbers with comma decimal separator")
  func testGermanDecimalSeparator() {
    let deLocale = Locale(identifier: "de_DE")
    #expect(Decimal.parse("1.000,50", locale: deLocale) == Decimal(string: "1000.50"))
    #expect(Decimal.parse("1.234.567,89", locale: deLocale) == Decimal(string: "1234567.89"))
  }

  // MARK: - Currency symbol stripping

  @Test("Strips common currency symbols")
  func testCurrencySymbolStripping() {
    let usLocale = Locale(identifier: "en_US")
    #expect(Decimal.parse("$1,000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("€1,000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("£1,000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("¥1000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("₩1000", locale: usLocale) == Decimal(1000))
    #expect(Decimal.parse("₹1,000", locale: usLocale) == Decimal(1000))
  }

  // MARK: - Whitespace handling

  @Test("Handles leading and trailing whitespace")
  func testWhitespaceHandling() {
    #expect(Decimal.parse("  1000  ") == Decimal(1000))
    #expect(Decimal.parse("\t1000\n") == Decimal(1000))
    #expect(Decimal.parse("$ 1,000 ", locale: Locale(identifier: "en_US")) == Decimal(1000))
  }

  // MARK: - Invalid input

  @Test("Returns nil for invalid input")
  func testInvalidInput() {
    #expect(Decimal.parse("abc") == nil)
    #expect(Decimal.parse("") == nil)
    #expect(Decimal.parse("   ") == nil)
    #expect(Decimal.parse("$") == nil)
  }

  // MARK: - Negative numbers

  @Test("Handles negative numbers")
  func testNegativeNumbers() {
    let usLocale = Locale(identifier: "en_US")
    #expect(Decimal.parse("-1000") == Decimal(-1000))
    #expect(Decimal.parse("-1,000", locale: usLocale) == Decimal(-1000))
    #expect(Decimal.parse("-1,000.50", locale: usLocale) == Decimal(string: "-1000.50"))
  }

  // MARK: - Default locale behavior

  @Test("Uses current locale by default")
  func testDefaultLocale() {
    // This test verifies the function works without explicit locale
    // The result depends on the system locale, so we just check it doesn't crash
    let result = Decimal.parse("1000")
    #expect(result == Decimal(1000))
  }
}

//
//  CurrencyService.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation

/// Represents a currency from ISO 4217
struct Currency: Identifiable, Hashable {
  let code: String
  let name: String
  let numericCode: String?
  let minorUnit: Int?

  var id: String { code }

  /// Flag emoji for the currency (best effort based on code)
  var flag: String {
    // Most currencies use first 2 letters as country code
    let countryCode = String(code.prefix(2)).uppercased()

    // Use generic money icon for special/regional currencies
    let specialCodes = ["XA", "XB", "XC", "XD", "XO", "XP", "XS", "XT", "XX", "XU"]
    if specialCodes.contains(countryCode) {
      return "💰"
    }

    // Convert country code to flag emoji
    // Regional indicator symbols: A-Z maps to 🇦-🇿 (U+1F1E6 to U+1F1FF)
    var flag = ""
    for char in countryCode.unicodeScalars {
      guard let scalar = UnicodeScalar(0x1F1E6 + char.value - 0x41) else {
        return "💰"
      }
      flag.append(String(scalar))
    }

    return flag
  }

  /// Display string for picker
  var displayName: String {
    "\(flag) \(code) - \(name)"
  }
}

/// Service for loading and managing currencies from ISO 4217 XML
@MainActor
class CurrencyService {
  static let shared = CurrencyService()

  private(set) var currencies: [Currency] = []

  private init() {
    loadCurrencies()
  }

  /// Load currencies from ISO 4217 XML file or fallback to defaults
  private func loadCurrencies() {
    // Try to load from bundle
    if let url = Bundle.main.url(forResource: "iso4217", withExtension: "xml"),
      let data = try? Data(contentsOf: url)
    {
      currencies = parseISO4217(data: data)
    }

    // If loading failed or no currencies found, use default set
    if currencies.isEmpty {
      currencies = defaultCurrencies()
    }

    // Sort by code for easy lookup
    currencies.sort { $0.code < $1.code }
  }

  /// Parse ISO 4217 XML format
  private func parseISO4217(data: Data) -> [Currency] {
    let parser = ISO4217Parser()
    let allCurrencies = parser.parse(data: data)

    // Remove duplicates by keeping only the first occurrence of each currency code
    var seen = Set<String>()
    return allCurrencies.filter { currency in
      guard !seen.contains(currency.code) else { return false }
      seen.insert(currency.code)
      return true
    }
  }

  /// Fallback currencies if XML not available
  private func defaultCurrencies() -> [Currency] {
    [
      Currency(code: "USD", name: "US Dollar", numericCode: "840", minorUnit: 2),
      Currency(code: "EUR", name: "Euro", numericCode: "978", minorUnit: 2),
      Currency(code: "GBP", name: "Pound Sterling", numericCode: "826", minorUnit: 2),
      Currency(code: "JPY", name: "Yen", numericCode: "392", minorUnit: 0),
      Currency(code: "CNY", name: "Yuan Renminbi", numericCode: "156", minorUnit: 2),
      Currency(code: "TWD", name: "New Taiwan Dollar", numericCode: "901", minorUnit: 2),
      Currency(code: "HKD", name: "Hong Kong Dollar", numericCode: "344", minorUnit: 2),
      Currency(code: "AUD", name: "Australian Dollar", numericCode: "036", minorUnit: 2),
      Currency(code: "CAD", name: "Canadian Dollar", numericCode: "124", minorUnit: 2),
      Currency(code: "CHF", name: "Swiss Franc", numericCode: "756", minorUnit: 2),
      Currency(code: "SGD", name: "Singapore Dollar", numericCode: "702", minorUnit: 2),
      Currency(code: "KRW", name: "Won", numericCode: "410", minorUnit: 0),
      Currency(code: "INR", name: "Indian Rupee", numericCode: "356", minorUnit: 2),
      Currency(code: "BRL", name: "Brazilian Real", numericCode: "986", minorUnit: 2),
      Currency(code: "MXN", name: "Mexican Peso", numericCode: "484", minorUnit: 2),
    ]
  }

  /// Find currency by code
  func currency(for code: String) -> Currency? {
    currencies.first { $0.code.uppercased() == code.uppercased() }
  }
}

/// Parser for ISO 4217 XML format
private class ISO4217Parser: NSObject, XMLParserDelegate {
  private var currencies: [Currency] = []
  private var currentElement = ""
  private var currentCode = ""
  private var currentName = ""
  private var currentNumericCode = ""
  private var currentMinorUnit = ""
  private var isFund = false

  func parse(data: Data) -> [Currency] {
    let parser = XMLParser(data: data)
    parser.delegate = self
    parser.parse()
    return currencies
  }

  func parser(
    _ parser: XMLParser, didStartElement elementName: String,
    namespaceURI: String?, qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    currentElement = elementName
    if elementName == "CcyNtry" {
      // Reset for new currency entry
      currentCode = ""
      currentName = ""
      currentNumericCode = ""
      currentMinorUnit = ""
      isFund = false
    } else if elementName == "CcyNm" {
      // Check if this is a fund currency
      isFund = attributeDict["IsFund"] == "true"
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    switch currentElement {
    case "Ccy":
      currentCode = trimmed

    case "CcyNm":
      currentName = trimmed

    case "CcyNbr":
      currentNumericCode = trimmed

    case "CcyMnrUnts":
      currentMinorUnit = trimmed

    default:
      break
    }
  }

  func parser(
    _ parser: XMLParser, didEndElement elementName: String,
    namespaceURI: String?, qualifiedName qName: String?
  ) {
    if elementName == "CcyNtry", !currentCode.isEmpty, !currentName.isEmpty, !isFund {
      // Only add if we have both code and name, and it's not a fund currency
      let minorUnit = Int(currentMinorUnit)
      let currency = Currency(
        code: currentCode,
        name: currentName,
        numericCode: currentNumericCode.isEmpty ? nil : currentNumericCode,
        minorUnit: minorUnit
      )
      currencies.append(currency)
    }
  }
}

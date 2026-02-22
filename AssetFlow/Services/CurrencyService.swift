//
//  CurrencyService.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation
import Observation

/// Represents a currency with code and display name.
struct Currency: Identifiable, Hashable {
  let code: String
  let name: String

  var id: String { code }

  /// Display string for picker (e.g., "USD - US Dollar")
  var displayName: String {
    "\(code.uppercased()) - \(name)"
  }
}

/// Service for loading and managing currencies.
///
/// Loads cached currencies on init (falling back to hardcoded defaults).
/// Can be refreshed with the full API-fetched list via `loadFromAPI()`,
/// which also persists the result to UserDefaults for offline use.
@Observable
@MainActor
class CurrencyService {
  static let shared = CurrencyService()

  private(set) var currencies: [Currency] = []

  private let cacheKey = "cachedCurrencyList"

  private init() {
    currencies = loadCachedCurrencies() ?? defaultCurrencies()
  }

  /// Fetches the full currency list from the API and replaces the local list.
  ///
  /// On success, caches the result to UserDefaults for future offline use.
  /// On failure, keeps the existing list.
  func loadFromAPI() async {
    let service = ExchangeRateService()
    do {
      let apiList = try await service.fetchCurrencyList()
      var newCurrencies: [Currency] = []
      for (code, name) in apiList {
        let upperCode = code.uppercased()
        guard !name.isEmpty else { continue }
        newCurrencies.append(Currency(code: upperCode, name: name))
      }
      newCurrencies.sort { $0.code < $1.code }
      if !newCurrencies.isEmpty {
        currencies = newCurrencies
        saveCurrenciesToCache(newCurrencies)
      }
    } catch {
      // Keep existing list on failure
    }
  }

  // MARK: - Cache

  private func saveCurrenciesToCache(_ currencies: [Currency]) {
    let encoded = currencies.map { ["code": $0.code, "name": $0.name] }
    UserDefaults.standard.set(encoded, forKey: cacheKey)
  }

  private func loadCachedCurrencies() -> [Currency]? {
    guard
      let cached = UserDefaults.standard.array(forKey: cacheKey) as? [[String: String]]
    else { return nil }
    let currencies = cached.compactMap { dict -> Currency? in
      guard let code = dict["code"], let name = dict["name"] else { return nil }
      return Currency(code: code, name: name)
    }
    return currencies.isEmpty ? nil : currencies
  }

  /// Default currencies — expanded set of common fiat + crypto
  private func defaultCurrencies() -> [Currency] {
    [
      Currency(code: "USD", name: "US Dollar"),
      Currency(code: "EUR", name: "Euro"),
      Currency(code: "GBP", name: "Pound Sterling"),
      Currency(code: "JPY", name: "Yen"),
      Currency(code: "CNY", name: "Yuan Renminbi"),
      Currency(code: "TWD", name: "New Taiwan Dollar"),
      Currency(code: "HKD", name: "Hong Kong Dollar"),
      Currency(code: "AUD", name: "Australian Dollar"),
      Currency(code: "CAD", name: "Canadian Dollar"),
      Currency(code: "CHF", name: "Swiss Franc"),
      Currency(code: "SGD", name: "Singapore Dollar"),
      Currency(code: "KRW", name: "Won"),
      Currency(code: "INR", name: "Indian Rupee"),
      Currency(code: "BRL", name: "Brazilian Real"),
      Currency(code: "MXN", name: "Mexican Peso"),
      Currency(code: "NZD", name: "New Zealand Dollar"),
      Currency(code: "SEK", name: "Swedish Krona"),
      Currency(code: "NOK", name: "Norwegian Krone"),
      Currency(code: "DKK", name: "Danish Krone"),
      Currency(code: "PLN", name: "Zloty"),
      Currency(code: "THB", name: "Baht"),
      Currency(code: "MYR", name: "Malaysian Ringgit"),
      Currency(code: "IDR", name: "Rupiah"),
      Currency(code: "PHP", name: "Philippine Peso"),
      Currency(code: "VND", name: "Dong"),
      Currency(code: "ZAR", name: "Rand"),
      Currency(code: "TRY", name: "Turkish Lira"),
      Currency(code: "ILS", name: "New Israeli Sheqel"),
      Currency(code: "AED", name: "UAE Dirham"),
      Currency(code: "SAR", name: "Saudi Riyal"),
      Currency(code: "BTC", name: "Bitcoin"),
      Currency(code: "ETH", name: "Ethereum"),
    ].sorted { $0.code < $1.code }
  }

  /// Find currency by code
  func currency(for code: String) -> Currency? {
    currencies.first { $0.code.uppercased() == code.uppercased() }
  }
}

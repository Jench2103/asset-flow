//
//  ExchangeRateService.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation

/// Response from Coinbase exchange rate API
struct ExchangeRateResponse: Codable {
  let data: ExchangeRateData
}

struct ExchangeRateData: Codable {
  let currency: String
  let rates: [String: String]
}

/// Service for fetching and caching exchange rates
@Observable
@MainActor
class ExchangeRateService {
  static let shared = ExchangeRateService()

  var rates: [String: Decimal] = [:]
  var isLoading = false
  var lastError: String?

  /// The base currency that all rates are relative to
  let baseCurrency: String

  private var lastFetchTime: Date?
  private let cacheDuration: TimeInterval = 3600  // 1 hour cache

  private init(baseCurrency: String = "USD") {
    self.baseCurrency = baseCurrency
  }

  /// Fetch exchange rates from Coinbase API
  func fetchRates() async {
    // Check if we have cached rates that are still valid
    if let lastFetch = lastFetchTime,
      Date().timeIntervalSince(lastFetch) < cacheDuration,
      !rates.isEmpty
    {
      return  // Use cached rates
    }

    isLoading = true
    lastError = nil

    do {
      let url = URL(
        string: "https://api.coinbase.com/v2/exchange-rates?currency=\(self.baseCurrency)")!

      let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))

      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200
      else {
        throw ExchangeRateError.invalidResponse
      }

      let exchangeRateResponse = try JSONDecoder().decode(
        ExchangeRateResponse.self, from: data)

      // Convert string rates to Decimal
      var newRates: [String: Decimal] = [:]
      for (currency, rateString) in exchangeRateResponse.data.rates {
        if let rate = Decimal(string: rateString) {
          newRates[currency] = rate
        }
      }

      rates = newRates
      lastFetchTime = Date()
      isLoading = false

    } catch let error as URLError {
      // Network-specific errors
      switch error.code {
      case .cancelled:
        // Expected when SwiftUI cancels a .task on view disappear; not a user-facing error.
        break

      case .notConnectedToInternet:
        lastError = "No internet connection. Using cached rates if available."

      case .timedOut:
        lastError = "Request timed out. Please try again."

      default:
        lastError = "Network error: \(error.localizedDescription)"
      }
      isLoading = false
    } catch {
      lastError = "Failed to fetch exchange rates: \(error.localizedDescription)"
      isLoading = false
    }
  }

  /// Convert amount from one currency to another using current rates
  func convert(amount: Decimal, from: String, to: String) -> Decimal {
    Self.convert(amount: amount, from: from, to: to, using: rates, baseCurrency: baseCurrency)
  }

  /// Convert amount from one currency to another using provided rates
  /// - Parameters:
  ///   - amount: Amount to convert
  ///   - from: Source currency code
  ///   - to: Target currency code
  ///   - rates: Exchange rates dictionary (currency code -> rate relative to baseCurrency)
  ///   - baseCurrency: The base currency that rates are relative to
  /// - Returns: Converted amount, or original amount if conversion not possible
  nonisolated static func convert(
    amount: Decimal, from: String, to: String, using rates: [String: Decimal],
    baseCurrency: String
  )
    -> Decimal
  {
    // If same currency, no conversion needed
    if from == to {
      return amount
    }

    // If converting from base currency
    if from == baseCurrency {
      guard let rate = rates[to] else { return amount }
      return amount * rate
    }

    // If converting to base currency
    if to == baseCurrency {
      guard let rate = rates[from] else { return amount }
      return rate > 0 ? amount / rate : amount
    }

    // Converting between two non-base currencies
    // First convert from source to base, then base to target
    guard let fromRate = rates[from], let toRate = rates[to] else {
      return amount
    }

    let amountInBase = fromRate > 0 ? amount / fromRate : amount
    return amountInBase * toRate
  }

  /// Get exchange rate for a specific currency pair
  func rate(from: String, to: String) -> Decimal? {
    if from == to {
      return 1
    }

    if from == baseCurrency {
      return rates[to]
    }

    if to == baseCurrency {
      guard let rate = rates[from], rate > 0 else { return nil }
      return 1 / rate
    }

    guard let fromRate = rates[from], let toRate = rates[to] else {
      return nil
    }

    guard fromRate > 0 else { return nil }
    return toRate / fromRate
  }
}

enum ExchangeRateError: Error {
  case invalidResponse
  case networkError
}

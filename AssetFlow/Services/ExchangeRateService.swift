//
//  ExchangeRateService.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation

/// Errors that can occur when fetching exchange rates.
enum ExchangeRateError: Error, LocalizedError {
  case networkUnavailable
  case invalidResponse
  case ratesNotFound

  var errorDescription: String? {
    switch self {
    case .networkUnavailable:
      return String(
        localized: "Network unavailable. Exchange rates could not be fetched.", table: "Services")

    case .invalidResponse:
      return String(localized: "Invalid response from exchange rate service.", table: "Services")

    case .ratesNotFound:
      return String(
        localized: "Exchange rates not found for the requested date.", table: "Services")
    }
  }
}

/// Service for fetching exchange rates from the fawazahmed0 currency API.
///
/// Uses cdn.jsdelivr.net as CDN host. Accepts a `URLSession` for testability.
final class ExchangeRateService: @unchecked Sendable {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  /// Fetches exchange rates for a given date and base currency.
  ///
  /// - Parameters:
  ///   - date: The date to fetch rates for (uses YYYY-MM-DD format)
  ///   - baseCurrency: The base currency code (lowercase, e.g., "usd")
  /// - Returns: Dictionary of currency code to rate
  /// - Throws: `ExchangeRateError`
  func fetchRates(for date: Date, baseCurrency: String) async throws -> [String: Double] {
    let base = baseCurrency.lowercased()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: date)

    let urlString =
      "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@\(dateString)/v1/currencies/\(base).min.json"

    guard let url = URL(string: urlString) else {
      throw ExchangeRateError.invalidResponse
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(from: url)
    } catch {
      throw ExchangeRateError.networkUnavailable
    }

    if let httpResponse = response as? HTTPURLResponse {
      if httpResponse.statusCode == 404 {
        throw ExchangeRateError.ratesNotFound
      }
      guard (200...299).contains(httpResponse.statusCode) else {
        throw ExchangeRateError.invalidResponse
      }
    }

    // Parse JSON: {"date": "...", "{base}": {code: rate, ...}}
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let ratesDict = json[base] as? [String: Any]
    else {
      throw ExchangeRateError.invalidResponse
    }

    var rates: [String: Double] = [:]
    for (key, value) in ratesDict {
      if let doubleValue = value as? Double {
        rates[key] = doubleValue
      } else if let intValue = value as? Int {
        rates[key] = Double(intValue)
      }
    }

    return rates
  }

  /// Fetches the full list of supported currencies.
  ///
  /// - Returns: Dictionary of currency code to currency name
  /// - Throws: `ExchangeRateError`
  func fetchCurrencyList() async throws -> [String: String] {
    let urlString =
      "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies.min.json"

    guard let url = URL(string: urlString) else {
      throw ExchangeRateError.invalidResponse
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(from: url)
    } catch {
      throw ExchangeRateError.networkUnavailable
    }

    if let httpResponse = response as? HTTPURLResponse {
      guard (200...299).contains(httpResponse.statusCode) else {
        throw ExchangeRateError.invalidResponse
      }
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
      throw ExchangeRateError.invalidResponse
    }

    return json
  }
}

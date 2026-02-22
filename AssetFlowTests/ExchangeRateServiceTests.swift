//
//  ExchangeRateServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation
import Testing

@testable import AssetFlow

// Top-level mock URLProtocol for testing
private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      client?.urlProtocolDidFinishLoading(self)
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

@Suite("ExchangeRate Service Tests", .serialized)
@MainActor
struct ExchangeRateServiceTests {

  private func createMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }

  // MARK: - Fetch Rates Tests

  @Test("Fetch rates returns valid parsed rates")
  func testFetchRatesSuccess() async throws {
    let session = createMockSession()
    let json = """
      {"date": "2026-02-22", "usd": {"eur": 0.92, "twd": 31.5, "jpy": 149.5}}
      """
    MockURLProtocol.requestHandler = { _ in
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, json.data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    let rates = try await service.fetchRates(
      for: Date(), baseCurrency: "usd")

    #expect(rates["eur"] == 0.92)
    #expect(rates["twd"] == 31.5)
    #expect(rates["jpy"] == 149.5)
  }

  @Test("Fetch rates throws networkUnavailable on error")
  func testFetchRatesNetworkError() async throws {
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      throw URLError(.notConnectedToInternet)
    }

    let service = ExchangeRateService(session: session)

    await #expect(throws: ExchangeRateError.self) {
      _ = try await service.fetchRates(for: Date(), baseCurrency: "usd")
    }
  }

  @Test("Fetch rates throws ratesNotFound on 404")
  func testFetchRatesNotFound() async throws {
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 404,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let service = ExchangeRateService(session: session)

    await #expect(throws: ExchangeRateError.ratesNotFound) {
      _ = try await service.fetchRates(for: Date(), baseCurrency: "usd")
    }
  }

  @Test("Fetch rates throws invalidResponse on malformed JSON")
  func testFetchRatesInvalidJSON() async throws {
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "not json".data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)

    await #expect(throws: ExchangeRateError.invalidResponse) {
      _ = try await service.fetchRates(for: Date(), baseCurrency: "usd")
    }
  }

  @Test("Fetch rates caches results by date and base")
  func testFetchRatesCaching() async throws {
    let session = createMockSession()
    var callCount = 0
    let json = """
      {"date": "2026-01-01", "usd": {"eur": 0.92}}
      """
    MockURLProtocol.requestHandler = { _ in
      callCount += 1
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, json.data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    _ = try await service.fetchRates(for: fixedDate, baseCurrency: "usd")
    _ = try await service.fetchRates(for: fixedDate, baseCurrency: "usd")

    #expect(callCount == 1)
  }

  // MARK: - Currency List Tests

  @Test("Fetch currency list returns valid dict")
  func testFetchCurrencyListSuccess() async throws {
    let session = createMockSession()
    let json = """
      {"usd": "United States Dollar", "eur": "Euro", "twd": "New Taiwan Dollar"}
      """
    MockURLProtocol.requestHandler = { _ in
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, json.data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    let list = try await service.fetchCurrencyList()

    #expect(list["usd"] == "United States Dollar")
    #expect(list["eur"] == "Euro")
    #expect(list.count == 3)
  }

  @Test("Fetch currency list caches results")
  func testFetchCurrencyListCaching() async throws {
    let session = createMockSession()
    var callCount = 0
    let json = """
      {"usd": "US Dollar"}
      """
    MockURLProtocol.requestHandler = { _ in
      callCount += 1
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, json.data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    _ = try await service.fetchCurrencyList()
    _ = try await service.fetchCurrencyList()

    #expect(callCount == 1)
  }
}

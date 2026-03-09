//
//  ExchangeRateServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation
import SwiftData
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

  // MARK: - Fetch Missing Rates Tests

  private func createSnapshotWithAsset(
    currency: String,
    container: ModelContainer
  ) -> Snapshot {
    let context = container.mainContext
    let snapshot = Snapshot(date: Date())
    context.insert(snapshot)

    let asset = Asset(name: "Test Asset \(UUID().uuidString)")
    asset.currency = currency
    context.insert(asset)

    let assetValue = SnapshotAssetValue(marketValue: 1000)
    assetValue.snapshot = snapshot
    assetValue.asset = asset
    context.insert(assetValue)

    return snapshot
  }

  private func mockSuccessHandler(baseCurrency: String) -> (URLRequest) throws -> (
    HTTPURLResponse, Data
  ) {
    { _ in
      let json = """
        {"date": "2026-01-01", "\(baseCurrency)": {"eur": 0.92, "twd": 31.5, "jpy": 149.5, "usd": 1.0}}
        """
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, json.data(using: .utf8)!)
    }
  }

  @Test("fetchMissingRates skips snapshots that already have exchange rates")
  func testFetchMissingRatesSkipsSnapshotsWithExistingRates() async {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let snapshot = createSnapshotWithAsset(currency: "EUR", container: container)

    // Attach an existing ExchangeRate
    let ratesJSON = try! JSONEncoder().encode(["eur": 0.92])
    let er = ExchangeRate(baseCurrency: "usd", ratesJSON: ratesJSON, fetchDate: snapshot.date)
    er.snapshot = snapshot
    context.insert(er)

    var networkCallCount = 0
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      networkCallCount += 1
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "{}".data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    await service.fetchMissingRates(
      snapshots: [snapshot],
      displayCurrency: "USD",
      modelContext: context
    )

    #expect(networkCallCount == 0)
  }

  @Test("fetchMissingRates skips snapshots that don't need conversion")
  func testFetchMissingRatesSkipsSnapshotsWithNoConversionNeeded() async {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let snapshot = createSnapshotWithAsset(currency: "USD", container: container)

    var networkCallCount = 0
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      networkCallCount += 1
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "{}".data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    await service.fetchMissingRates(
      snapshots: [snapshot],
      displayCurrency: "USD",
      modelContext: context
    )

    #expect(networkCallCount == 0)
    #expect(snapshot.exchangeRate == nil)
  }

  @Test("fetchMissingRates fetches for snapshot missing rates with multi-currency assets")
  func testFetchMissingRatesFetchesForSnapshotMissingRates() async {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let snapshot = createSnapshotWithAsset(currency: "EUR", container: container)

    let session = createMockSession()
    MockURLProtocol.requestHandler = mockSuccessHandler(baseCurrency: "usd")

    let service = ExchangeRateService(session: session)
    await service.fetchMissingRates(
      snapshots: [snapshot],
      displayCurrency: "USD",
      modelContext: context
    )

    #expect(snapshot.exchangeRate != nil)
    #expect(snapshot.exchangeRate?.baseCurrency == "usd")
    #expect(snapshot.exchangeRate?.rates["eur"] == 0.92)
  }

  @Test("fetchMissingRates continues on per-snapshot failure")
  func testFetchMissingRatesContinuesOnPerSnapshotFailure() async {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // First snapshot — will fail (different date triggers different URL)
    let snapshot1 = Snapshot(date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)
    context.insert(snapshot1)
    let asset1 = Asset(name: "Fail Asset")
    asset1.currency = "EUR"
    context.insert(asset1)
    let av1 = SnapshotAssetValue(marketValue: 500)
    av1.snapshot = snapshot1
    av1.asset = asset1
    context.insert(av1)

    // Second snapshot — will succeed
    let snapshot2 = Snapshot(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!)
    context.insert(snapshot2)
    let asset2 = Asset(name: "Success Asset")
    asset2.currency = "TWD"
    context.insert(asset2)
    let av2 = SnapshotAssetValue(marketValue: 1000)
    av2.snapshot = snapshot2
    av2.asset = asset2
    context.insert(av2)

    var requestCount = 0
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      requestCount += 1
      if requestCount == 1 {
        // First request fails with 404
        let response = HTTPURLResponse(
          url: URL(string: "https://example.com")!,
          statusCode: 404,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, Data())
      } else {
        // Second request succeeds
        let json = """
          {"date": "2026-01-01", "usd": {"eur": 0.92, "twd": 31.5, "jpy": 149.5}}
          """
        let response = HTTPURLResponse(
          url: URL(string: "https://example.com")!,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil
        )!
        return (response, json.data(using: .utf8)!)
      }
    }

    let service = ExchangeRateService(session: session)
    await service.fetchMissingRates(
      snapshots: [snapshot1, snapshot2],
      displayCurrency: "USD",
      modelContext: context
    )

    // First snapshot should have no exchange rate (failed)
    #expect(snapshot1.exchangeRate == nil)
    // Second snapshot should have exchange rate (succeeded despite first failing)
    #expect(snapshot2.exchangeRate != nil)
    #expect(snapshot2.exchangeRate?.baseCurrency == "usd")
  }

  @Test("fetchMissingRates handles empty snapshot list")
  func testFetchMissingRatesHandlesEmptySnapshotList() async {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    var networkCallCount = 0
    let session = createMockSession()
    MockURLProtocol.requestHandler = { _ in
      networkCallCount += 1
      let response = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, "{}".data(using: .utf8)!)
    }

    let service = ExchangeRateService(session: session)
    await service.fetchMissingRates(
      snapshots: [],
      displayCurrency: "USD",
      modelContext: context
    )

    #expect(networkCallCount == 0)
  }
}

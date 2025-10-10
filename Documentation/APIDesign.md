# API and Integration Design

## Preface

**Purpose of this Document**

This document describes the design of external integrations and internal API patterns for AssetFlow. It covers both **external APIs** (third-party services for data) and **internal APIs** (how components communicate within the app).

**What This Document Covers**

- **External API Integrations**: Third-party services for asset prices, market data, etc.
- **Internal API Design**: Service layer interfaces, ViewModel contracts, data access patterns
- **Data Import/Export**: File formats and integration with other financial tools
- **Future Integration Points**: Planned external connections

**What This Document Does NOT Cover**

- User interface design (see [UserInterfaceDesign.md](UserInterfaceDesign.md))
- Business logic calculations (see [BusinessLogic.md](BusinessLogic.md))
- Data model structure (see [DataModel.md](DataModel.md))

**Current Status**

🚧 **This document is a work in progress.** AssetFlow is currently a **standalone, offline application** with no external API dependencies. This document establishes the framework for future integrations while documenting internal API patterns as they are developed.

**Design Philosophy**

- **Offline-First**: App fully functional without internet
- **Optional Integrations**: External APIs are convenience features, not requirements
- **Fail Gracefully**: If API unavailable, fall back to manual entry or cached data
- **Privacy-Preserving**: Minimize data sent to third parties
- **Standard Formats**: Use open formats for import/export (CSV, JSON)

**Related Documentation**

- [Architecture.md](Architecture.md) - MVVM layers and data flow
- [SecurityAndPrivacy.md](SecurityAndPrivacy.md) - Data security and privacy
- [DataModel.md](DataModel.md) - Data structures

______________________________________________________________________

## Development Phases

### Phase 1-2: No External APIs (Current)

**Status**: Fully offline, no network features

**Data Entry**: Manual user input only

**Internal APIs**: Direct SwiftData access via `@Query` and `@Environment(\.modelContext)`

______________________________________________________________________

### Phase 3: Asset Price Updates (Planned)

**External Integration**: Financial data API for current prices

**Use Cases**

- Automatically update stock prices
- Automatically update cryptocurrency prices
- Display current market data

**Requirements**

- HTTPS only
- API key management
- Rate limiting and caching
- Error handling (fallback to manual entry)

______________________________________________________________________

### Phase 4+: Advanced Integrations (Future)

**Potential Integrations**

- Historical price data (charting)
- News and market data
- Brokerage connections (read-only, view holdings)
- Data sync across devices (iCloud)
- Export to tax software

______________________________________________________________________

## External API Integrations

### Asset Price Data API (Phase 3)

**Purpose**: Fetch current market prices for stocks, cryptocurrencies, and other assets

______________________________________________________________________

#### Provider Selection

**Evaluation Criteria**

- Free tier or affordable pricing
- Reliable uptime
- Comprehensive coverage (stocks, crypto, forex, etc.)
- API rate limits
- Privacy policy (data usage)

**Candidate Providers**

1. **Alpha Vantage**

   - Free tier: 5 requests/min, 500 requests/day
   - Coverage: Stocks, forex, crypto
   - HTTPS, JSON API

1. **Yahoo Finance API** (unofficial)

   - Free (unofficial scrapers available)
   - Coverage: Stocks, ETFs, crypto
   - Risk: Unofficial, may break

1. **CoinGecko API** (for crypto)

   - Free tier: 50 calls/min
   - Coverage: Comprehensive crypto
   - Reliable, well-documented

1. **IEX Cloud**

   - Free tier: 50,000 messages/month
   - Coverage: Stocks, ETFs
   - Official, reliable

**Recommendation** (to be decided during implementation)

- Use multiple providers based on asset type
  - Stocks: IEX Cloud or Alpha Vantage
  - Crypto: CoinGecko
  - Forex: Alpha Vantage
- Fallback: Manual entry if API unavailable

______________________________________________________________________

#### API Request Pattern

**Request Flow**

1. User opens asset detail or refreshes data
1. App checks cache (timestamp)
1. If cache stale (>15 minutes), fetch from API
1. Update asset's `currentValue` in SwiftData
1. Display updated value with timestamp ("Updated 5 min ago")

**Batching**

- Fetch multiple asset prices in single request (if API supports)
- Reduces API calls, faster updates

**Rate Limiting**

- Track API calls per minute/day
- Display warning if approaching limit
- Disable auto-refresh if limit reached, require manual refresh

______________________________________________________________________

#### API Response Handling

**Success Response** (Example: IEX Cloud)

```json
{
  "symbol": "AAPL",
  "latestPrice": 175.43,
  "latestUpdate": 1672531200000,
  "currency": "USD"
}
```

**Mapping to AssetFlow**

- Parse `latestPrice`
- Convert to `Decimal`
- Update asset's `currentValue`
- Store `latestUpdate` timestamp (for staleness indicator)

**Error Handling**

- HTTP errors (500, 503): Retry with exponential backoff
- 404 (symbol not found): Notify user, suggest checking symbol
- 429 (rate limit): Display message, disable auto-refresh
- Network unreachable: Use cached value, notify user app is offline

______________________________________________________________________

#### Privacy Considerations

**Data Sent to API**

- Asset symbols/tickers (e.g., "AAPL", "BTC")
- No user identifiable information
- No portfolio values or quantities

**Minimization**

- Only send symbols user explicitly added
- Batch requests to reduce identifiable patterns

**Transparency**

- Inform user that symbols are sent to third-party API
- Privacy setting: "Enable automatic price updates" (opt-in)

______________________________________________________________________

#### API Key Management

**Storage**

- Store API keys in **Keychain** (secure, OS-managed)
- Never hardcode keys in source code

**User-Provided Keys** (Optional)

- Allow advanced users to provide their own API keys
- Documented in settings screen
- Benefits: Higher rate limits, user control

**Default Keys**

- Developer provides default API key (free tier)
- Shared across all users (rate limit shared)
- User encouraged to get own key if heavy usage

______________________________________________________________________

#### Caching Strategy

**Cache Duration**

- Stock prices: 15 minutes during market hours, 1 hour after close
- Crypto prices: 5 minutes (24/7 markets)
- Forex: 15 minutes

**Cache Storage**

- Store in SwiftData alongside asset (add `lastPriceUpdate: Date?` field)
- Or: In-memory cache (lost on app restart)

**Cache Invalidation**

- Manual refresh: Always fetch fresh data
- Auto-refresh: Respect cache duration
- User preference: Adjust cache duration in settings

______________________________________________________________________

### Historical Price Data API (Phase 4)

**Purpose**: Fetch historical prices for performance charting

**Data Required**

- Date range
- Daily closing prices
- Volume (optional)

**Provider**: Same as current price API (Alpha Vantage, IEX Cloud)

**Storage**

- Option 1: Store historical data in SwiftData (new model: `PriceHistory`)
- Option 2: Fetch on-demand, cache temporarily

**Use Case**

- Display performance chart over time
- Calculate time-weighted returns

______________________________________________________________________

### Brokerage Integration (Phase 4+)

**Purpose**: Automatically import holdings from brokerage accounts

**Challenges**

- Requires OAuth or API credentials
- Each brokerage has different API
- Security and privacy concerns (user credentials)

**Potential Solutions**

- Use aggregator services (Plaid, Yodlee)
- Read-only access
- Explicit user consent

**Decision**: Defer to Phase 4+, high complexity

______________________________________________________________________

## Internal API Design

### Service Layer (To Be Implemented)

**Purpose**: Encapsulate business logic and data access

**Pattern**: Repository/Service pattern

**Benefits**

- Separate concerns (ViewModel doesn't directly access SwiftData)
- Testable (mock services in tests)
- Reusable logic across ViewModels

______________________________________________________________________

#### Service Interfaces

**AssetService**

```swift
protocol AssetServiceProtocol {
    func fetchAssets() -> [Asset]
    func createAsset(_ asset: Asset) throws
    func updateAsset(_ asset: Asset) throws
    func deleteAsset(_ asset: Asset) throws
    func refreshAssetPrice(_ asset: Asset) async throws
}
```

**TransactionService**

```swift
protocol TransactionServiceProtocol {
    func fetchTransactions(for asset: Asset) -> [Transaction]
    func recordTransaction(_ transaction: Transaction) throws
    func validateTransaction(_ transaction: Transaction) -> ValidationResult
}
```

**PortfolioService**

```swift
protocol PortfolioServiceProtocol {
    func fetchPortfolios() -> [Portfolio]
    func createPortfolio(_ portfolio: Portfolio) throws
    func calculateAllocation(for portfolio: Portfolio) -> [String: Decimal]
    func suggestRebalancing(for portfolio: Portfolio) -> [RebalancingAction]
}
```

______________________________________________________________________

#### Implementation Pattern

**Service Implementation** (Example: AssetService)

```swift
class AssetService: AssetServiceProtocol {
    private let modelContext: ModelContext
    private let priceAPI: PriceAPIClient

    init(modelContext: ModelContext, priceAPI: PriceAPIClient) {
        self.modelContext = modelContext
        self.priceAPI = priceAPI
    }

    func fetchAssets() -> [Asset] {
        // Use SwiftData to fetch
    }

    func refreshAssetPrice(_ asset: Asset) async throws {
        let price = try await priceAPI.fetchPrice(symbol: asset.symbol)
        // Create a new price history entry instead of mutating the asset
        let newPriceRecord = PriceHistory(date: Date(), price: price, asset: asset)
        modelContext.insert(newPriceRecord)
        // SwiftData will auto-save the new record
    }
}
```

**ViewModel Usage**

```swift
class AssetListViewModel: ObservableObject {
    private let assetService: AssetServiceProtocol
    @Published var assets: [Asset] = []

    init(assetService: AssetServiceProtocol) {
        self.assetService = assetService
    }

    func loadAssets() {
        assets = assetService.fetchAssets()
    }

    func refreshPrices() async {
        for asset in assets {
            try? await assetService.refreshAssetPrice(asset)
        }
    }
}
```

______________________________________________________________________

### ViewModel Contracts

**Purpose**: Define ViewModel responsibilities and interfaces

**Pattern**: ViewModel exposes `@Published` properties for View binding

**Example: AssetDetailViewModel**

```swift
class AssetDetailViewModel: ObservableObject {
    @Published var asset: Asset
    @Published var transactions: [Transaction]
    @Published var unrealizedGain: Decimal
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func loadData()
    func refreshPrice() async
    func deleteAsset() throws
}
```

**View Binding**

```swift
struct AssetDetailView: View {
    @StateObject var viewModel: AssetDetailViewModel

    var body: some View {
        // Bind to viewModel.asset, viewModel.unrealizedGain, etc.
    }
}
```

______________________________________________________________________

### Data Access Patterns

**Direct SwiftData Access** (Current - Phase 1-2)

```swift
@Query var assets: [Asset]
@Environment(\.modelContext) var modelContext
```

**Pros**: Simple, direct, minimal boilerplate

**Cons**: View tied to SwiftData, harder to test, logic in View

______________________________________________________________________

**Service Layer Access** (Phase 3+)

```swift
@StateObject var viewModel: AssetListViewModel
```

**Pros**: Testable, separation of concerns, reusable logic

**Cons**: More code, more complexity

**Decision**: Use direct SwiftData for Phase 1-2, introduce services in Phase 3 when external API needed

______________________________________________________________________

## Data Import/Export

### Export Formats

**CSV Export** (Phase 2+)

**Purpose**: Backup, use in Excel/Google Sheets

**Assets CSV**

```csv
Name,Type,Symbol,Quantity,Current Value,Cost Basis,Portfolio
Apple Inc.,Stock,AAPL,10,1650.00,1500.00,Tech
Bitcoin,Cryptocurrency,BTC,0.5,12500.00,10000.00,Crypto
```

**Transactions CSV**

```csv
Date,Type,Asset,Quantity,Price,Total,Notes
2025-01-15,Buy,AAPL,10,150.00,1500.00,"Initial purchase"
2025-02-01,Dividend,AAPL,,,25.50,"Quarterly dividend"
```

**Implementation**

- Generate CSV from SwiftData models
- Use standard CSV library or manual string building
- Offer "Export All" or "Export Selected Portfolio"

______________________________________________________________________

**JSON Export** (Phase 3+)

**Purpose**: Structured data, easier to re-import or use in other apps

**Schema**

```json
{
  "version": "1.0",
  "exportDate": "2025-10-09T12:00:00Z",
  "portfolios": [
    {
      "name": "Tech Portfolio",
      "assets": [
        {
          "name": "Apple Inc.",
          "type": "Stock",
          "symbol": "AAPL",
          "quantity": 10,
          "currentValue": 1650.00,
          "costBasis": 1500.00,
          "transactions": [...]
        }
      ]
    }
  ]
}
```

**Implementation**

- Use `Codable` to serialize models
- Pretty-print JSON for readability

______________________________________________________________________

### Import Formats

**CSV Import** (Phase 3+)

**Purpose**: Bulk import from other tools (Mint, Personal Capital, spreadsheet)

**Challenges**

- Different tools use different CSV formats
- Mapping columns to AssetFlow fields
- Validation and error handling

**Approach**

- Define standard template (user fills in)
- Provide column mapping UI (advanced)
- Validate each row, report errors
- Preview before import

**Example Template**

```csv
AssetName,AssetType,Symbol,Quantity,CostBasis
Apple Inc.,Stock,AAPL,10,1500.00
```

______________________________________________________________________

**JSON Import** (Phase 3+)

**Purpose**: Re-import AssetFlow export or import from compatible tools

**Schema Versioning**

- Include `version` field in JSON
- Handle schema migrations if format changes

**Validation**

- Parse JSON
- Validate structure and required fields
- Check for duplicates (merge or skip)
- Import in transaction (all-or-nothing)

______________________________________________________________________

### iCloud Sync (Phase 4)

**Approach**: Use SwiftData built-in iCloud sync or CloudKit

**SwiftData iCloud Sync**

- Enable in Xcode project settings
- Automatic sync across devices
- Minimal code changes

**Considerations**

- Conflict resolution (if edited on multiple devices)
- Privacy (data in iCloud, encrypted by Apple)
- User must opt-in (settings toggle)

**Implementation**

- Add iCloud capability to project
- Configure `ModelContainer` with CloudKit option
- Test with multiple devices

______________________________________________________________________

## API Error Handling

### Error Types

**Network Errors**

- No internet connection
- Timeout
- Server unreachable

**API Errors**

- 400 Bad Request (invalid symbol)
- 401 Unauthorized (invalid API key)
- 429 Too Many Requests (rate limit)
- 500 Server Error

**Data Errors**

- Malformed response (invalid JSON)
- Missing required fields
- Unexpected data types

______________________________________________________________________

### Error Handling Strategy

**User-Facing Errors**

- Display clear, actionable error messages
- Suggest solutions (e.g., "Check your internet connection")
- Provide retry option

**Example**

```
Failed to update prices
Unable to reach the price data service. Check your internet connection and try again.
[Retry] [Dismiss]
```

**Developer Errors**

- Log errors with `os.log` (not `print()`)
- Include context (which API, which asset)
- No sensitive data in logs

**Graceful Degradation**

- If API fails, use cached/manual data
- Display staleness indicator ("Price as of 2 hours ago")
- App remains functional without API

______________________________________________________________________

## Rate Limiting and Performance

### API Rate Limit Management

**Track Usage**

- Count API calls per minute/day
- Store in UserDefaults or in-memory
- Reset counters at appropriate intervals

**Throttle Requests**

- Batch updates (fetch multiple assets in one call)
- Delay between requests if approaching limit
- Disable auto-refresh if limit reached

**User Notification**

- Warn when nearing limit (e.g., 80% of daily quota)
- Display remaining quota in settings

______________________________________________________________________

### Caching Strategy

Fetched prices are not cached temporarily; they are persisted as a permanent record of the asset's value at a point in time.

**Storage**

- When a price is fetched from an external API, a new `PriceHistory` record is created and stored in SwiftData.
- This creates a complete, auditable log of all price data, whether entered manually or fetched automatically.

**Staleness**

- The "current" price is simply the latest entry in the `PriceHistory` for a given asset.
- The app can decide whether to fetch a new price based on the timestamp of the latest `PriceHistory` record (e.g., if it's more than 15 minutes old).

______________________________________________________________________

## Testing External APIs

### Mocking API Responses

**Purpose**: Test app behavior without hitting real API

**Approach**

- Define API client protocol
- Implement mock client for tests
- Inject mock client into services/ViewModels

**Example**

```swift
protocol PriceAPIClient {
    func fetchPrice(symbol: String) async throws -> Decimal
}

class MockPriceAPIClient: PriceAPIClient {
    var priceToReturn: Decimal = 100.0
    var shouldThrowError: Bool = false

    func fetchPrice(symbol: String) async throws -> Decimal {
        if shouldThrowError { throw APIError.networkError }
        return priceToReturn
    }
}
```

**Test**

```swift
func testRefreshPriceSuccess() async throws {
    let mockAPI = MockPriceAPIClient()
    mockAPI.priceToReturn = 150.0
    let service = AssetService(modelContext: context, priceAPI: mockAPI)

    try await service.refreshAssetPrice(asset)
    XCTAssertEqual(asset.currentValue, 150.0)
}
```

______________________________________________________________________

### Integration Testing

**Purpose**: Verify real API integration works

**Approach**

- Use real API client in integration tests
- Require API key (environment variable or test config)
- Run periodically (not on every commit)
- Handle rate limits (use separate test API key)

**Example**

```swift
func testRealAPIIntegration() async throws {
    let apiKey = ProcessInfo.processInfo.environment["API_KEY"]!
    let apiClient = RealPriceAPIClient(apiKey: apiKey)

    let price = try await apiClient.fetchPrice(symbol: "AAPL")
    XCTAssertGreaterThan(price, 0)
}
```

______________________________________________________________________

## Future API Enhancements

### Webhooks/Push Notifications (Phase 4+)

**Purpose**: Real-time price alerts

**Approach**

- Subscribe to price changes for tracked assets
- Receive push notification when threshold met (e.g., "AAPL crossed $200")

**Requirements**

- Push notification capability
- Backend service (or third-party notification service)
- User opt-in

______________________________________________________________________

### Open Banking / Brokerage APIs (Phase 4+)

**Purpose**: Automatically sync holdings from brokerage

**Challenges**

- Each brokerage has different API (if any)
- Requires user credentials (security risk)
- OAuth flows, API rate limits

**Solutions**

- Use aggregator (Plaid, Yodlee) - easier but adds dependency
- Direct integrations with major brokerages (Robinhood, Fidelity, etc.)
- Read-only access, explicit user consent

**Privacy**

- User credentials never stored by AssetFlow
- OAuth tokens stored in Keychain
- User can revoke access anytime

______________________________________________________________________

## API Documentation

### Internal API Documentation

**Approach**

- Inline code documentation with Xcode comments (`///`)
- Protocol documentation (expected behavior)
- Example usage in comments

**Example**

```swift
/// Fetches the current market price for the given asset symbol.
/// - Parameter symbol: The ticker symbol (e.g., "AAPL", "BTC-USD")
/// - Returns: The current price as a `Decimal`
/// - Throws: `APIError.networkError` if network unreachable,
///           `APIError.invalidSymbol` if symbol not found
func fetchPrice(symbol: String) async throws -> Decimal
```

______________________________________________________________________

### External API Integration Docs

**Document in This File**

- Which APIs used
- How to obtain API keys
- Rate limits and pricing
- Example requests/responses
- Error codes and handling

**Update When**

- New API added
- API provider changed
- API endpoints/format changed

______________________________________________________________________

## References

### External API Documentation

**Financial Data APIs**

- [Alpha Vantage](https://www.alphavantage.co/documentation/)
- [IEX Cloud](https://iexcloud.io/docs/)
- [CoinGecko API](https://www.coingecko.com/en/api/documentation)
- [Yahoo Finance API](https://www.yahoofinanceapi.com/) (unofficial)

**Aggregation Services**

- [Plaid](https://plaid.com/docs/) - Brokerage and bank data
- [Yodlee](https://developer.yodlee.com/) - Financial data aggregation

### Apple Documentation

- [URLSession](https://developer.apple.com/documentation/foundation/urlsession) - Networking
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services) - API key storage
- [CloudKit](https://developer.apple.com/documentation/cloudkit) - iCloud sync

### Best Practices

- [RESTful API Design](https://restfulapi.net/)
- [API Security Best Practices](https://owasp.org/www-project-api-security/)

______________________________________________________________________

**Document Status**: 🚧 Initial framework - update when APIs are integrated

**Last Updated**: 2025-10-09

**Next Action**: Implement Phase 3 price API integration (select provider, implement client, add caching)

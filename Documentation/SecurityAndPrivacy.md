# Security and Privacy

## Preface

**Purpose of this Document**

This document outlines the security and privacy considerations for AssetFlow, a personal finance application handling sensitive financial data. It describes the measures taken to protect user data, ensure privacy, and maintain secure operation across macOS, iOS, and iPadOS platforms.

**What This Document Covers**

- **Data Security**: Encryption, storage security, secure communication
- **Privacy Principles**: What data is collected, how it's used, and user control
- **Platform Security**: Leveraging Apple platform security features
- **Threat Model**: Potential risks and mitigations
- **Compliance**: Best practices and regulatory considerations (if applicable)
- **Incident Response**: Handling security issues

**What This Document Does NOT Cover**

- Authentication/authorization (currently single-user, local app)
- Network security (no current network features)
- Multi-user access control (future feature)

**Current Status**

🚧 **This document establishes the security and privacy framework.** AssetFlow is a **local-first, single-user application** with data stored exclusively on the user's device. Many security concerns are inherently mitigated by this architecture, but best practices are still followed.

**Philosophy**

AssetFlow's security and privacy approach:

1. **Privacy by Design**: Minimal data collection, user owns all data
1. **Local-First**: Data stays on user's device by default
1. **Platform Trust**: Leverage Apple's security infrastructure
1. **Transparency**: Clear communication about data handling
1. **User Control**: Users can export, delete, or back up their data

**Related Documentation**

- [Architecture.md](Architecture.md) - System architecture and data flow
- [DataModel.md](DataModel.md) - Data structures and relationships

______________________________________________________________________

## Threat Model

### Assets to Protect

**Sensitive Data**

- Financial asset values and holdings
- Transaction history (purchase prices, amounts, dates)
- Portfolio composition
- Investment plans and goals
- Personal financial strategy

**Sensitivity Level**: **High**

- Exposure could reveal user's wealth, investment decisions, financial situation
- Not authentication credentials, but valuable for profiling or identity theft context

______________________________________________________________________

### Potential Threats

**Local Device Threats**

1. **Physical Device Access**

   - Risk: Unauthorized person accesses unlocked device
   - Impact: View sensitive financial data

1. **Device Theft**

   - Risk: Lost or stolen device
   - Impact: Access to data if device not protected

1. **Malware/Malicious Apps**

   - Risk: Malicious software on device
   - Impact: Data exfiltration, tampering

1. **Backup Exposure**

   - Risk: Unencrypted backups accessible
   - Impact: Data leaked through backup files

**Future Threats** (with network features)

5. **Network Interception**

   - Risk: Man-in-the-middle attacks on network traffic
   - Impact: Data exposure during sync/API calls

1. **Cloud Storage Breach**

   - Risk: iCloud account compromised
   - Impact: Access to synced data

**Insider Threats**

7. **Developer Access** (minimal risk - local app)
   - Risk: Developer could theoretically access diagnostic data
   - Mitigation: No analytics/telemetry by default

______________________________________________________________________

### Mitigations

**Device-Level Security** (Apple Platform Features)

1. **Device Encryption**: All modern iOS/macOS devices encrypt storage by default
1. **Device Passcode/Biometrics**: Enforced by OS, protects device access
1. **App Sandbox**: macOS/iOS sandbox isolates app data from other apps
1. **Keychain**: Secure storage for sensitive data (if needed in future)
1. **Code Signing**: App signed by developer, ensures integrity

**Application-Level Security**

1. **Local Data Only**: No network transmission of financial data (Phase 1-3)
1. **SwiftData Encryption**: Leverage platform database encryption
1. **No Logging of Sensitive Data**: Financial values not logged to console
1. **Input Validation**: Prevent malformed data injection
1. **Secure Deletion**: Properly delete data when user requests

______________________________________________________________________

## Data Security

### Data Storage

**SwiftData Persistence**

- **Location**: App sandbox directory (isolated from other apps)
- **Encryption**: Encrypted at rest by iOS/macOS file system
  - iOS: All files encrypted by default (Data Protection)
  - macOS: Encrypted if FileVault enabled (recommended)

**Backup Security**

- **iOS Backups**:
  - iCloud backup: Encrypted in transit and at rest
  - iTunes/Finder backup: Can be encrypted (user setting)
- **macOS Time Machine**:
  - Encrypted if Time Machine encryption enabled (user setting)

**Recommendation to Users**

- Enable device passcode/password
- Enable FileVault (macOS)
- Enable encrypted backups

______________________________________________________________________

### Data at Rest

**File System Encryption**

- **iOS**: Automatic, uses hardware-based encryption
- **macOS**: FileVault (user must enable)

**SwiftData Encryption**

- SwiftData uses SQLite under the hood
- Encrypted by file system encryption
- No additional app-level encryption needed (redundant)

**Future Enhancement**: SQLite Encryption Extension (SQLCipher)

- If extra layer desired (defense in depth)
- Adds complexity, key management
- Not necessary for Phase 1-3

______________________________________________________________________

### Data in Transit (Future)

**Current State**: No network features, no data transmission

**Future (Phase 4+): API Calls for Price Updates**

**Requirements**

- HTTPS only (TLS 1.2+)
- Certificate pinning (optional, for critical APIs)
- No transmission of user's portfolio data to third parties
- API calls: Only asset symbols/tickers for price lookup

**Privacy Consideration**

- Price lookup reveals which assets user tracks
- Mitigation: Use privacy-respecting APIs or batch requests

**Future: iCloud Sync**

- Use Apple's CloudKit or SwiftData iCloud sync
- End-to-end encrypted by Apple
- User must opt-in to iCloud sync

______________________________________________________________________

## Privacy

### Data Collection

**What Data is Collected**

- **User-Entered Financial Data**: Assets, portfolios, transactions, investment plans
- **Computed Data**: Calculations, allocations (derived from user data)

**What Data is NOT Collected**

- No personal identifiers (name, email, phone)
- No analytics or telemetry (no tracking)
- No usage data sent to developer or third parties
- No location data
- No contacts or photos access

**Data Ownership**

- **User owns 100% of their data**
- Data stored only on user's device (and their iCloud, if they opt in)
- No server-side storage by developer

______________________________________________________________________

### Data Usage

**Within the App**

- Data used solely for app functionality (calculations, displays, reports)
- No secondary use (e.g., no ads, no profiling)

**With Third Parties**

- **Phase 1-3**: No third-party data sharing (no network features)
- **Phase 4+ (API for prices)**: Only asset symbols sent, not user's holdings or values
- No data sold or shared with advertisers, brokers, or other entities

______________________________________________________________________

### User Control

**Data Export**

- User can export data to CSV or JSON (future feature)
- Enables backup, migration to other tools
- User can manage exported files securely

**Data Deletion**

- User can delete individual assets, portfolios, transactions
- User can delete all data (reset app)
- Uninstalling app removes all local data

**Data Portability**

- Export format should be standard (CSV, JSON)
- Enables switching to other financial tools

______________________________________________________________________

### Privacy Policy

**Requirement**

- If app distributed via App Store, privacy policy may be required
- Even if no data is collected, App Store requires privacy disclosure

**AssetFlow Privacy Disclosure** (Draft)

> AssetFlow does not collect, transmit, or share any personal or financial data. All data you enter is stored locally on your device and optionally in your iCloud account (if you enable iCloud sync). We do not track your usage, run analytics, or share any information with third parties. You own your data completely.

**Future (with network features)**

> AssetFlow may retrieve current asset prices from third-party financial data providers. Only the asset symbols (e.g., "AAPL") are sent to these providers to obtain prices; your holdings, values, or personal information are never transmitted.

______________________________________________________________________

## Platform Security Features

### macOS Security

**App Sandbox**

- Enabled: Yes (App Store requirement)
- Restricts file system access to app's container
- Restricts network access (can be enabled when needed)
- Restricts system resources

**Hardened Runtime**

- Enabled for distribution
- Prevents code injection, memory tampering
- Required for notarization (App Store/distribution)

**Code Signing**

- App signed with Developer ID
- Ensures integrity, verifies developer

**Gatekeeper**

- macOS checks signed apps before launch
- Prevents running tampered or malicious apps

______________________________________________________________________

### iOS/iPadOS Security

**App Sandbox**

- All iOS apps sandboxed by default
- Strict isolation from other apps

**Data Protection**

- Files encrypted by default
- Encryption keys tied to device passcode
- Highest protection level: "Complete Protection" (file inaccessible when device locked)

**App Transport Security (ATS)**

- Enforces HTTPS for network connections
- Prevents insecure HTTP (future network features)

**Code Signing**

- All apps signed
- iOS verifies signature on every launch

______________________________________________________________________

### Keychain (Future Use)

**Purpose**

- Secure storage for passwords, API keys, encryption keys
- Encrypted, access controlled by OS

**Potential Use in AssetFlow**

- Store API keys for price data services (Phase 4+)
- Store encryption keys (if app-level encryption added)
- NOT needed for user's financial data (SwiftData sufficient)

______________________________________________________________________

## Secure Coding Practices

### Input Validation

**Financial Inputs**

- Validate all user inputs (amounts, quantities, dates)
- Use `Decimal` type (no string-to-float injection risks)
- Reject invalid formats, negative values where inappropriate
- Sanitize text inputs (names, descriptions) to prevent issues

**Transaction Validation**

- Enforce business rules (see [BusinessLogic.md](BusinessLogic.md))
- Prevent inconsistent state (e.g., selling more than owned)

______________________________________________________________________

### No Sensitive Data Logging

**Prohibition**: Never log financial values, transaction details, or user data to console

**Custom Rule** (SwiftLint enforced)

- No `print()` statements allowed
- Use `os.log` with appropriate log levels
- Avoid logging sensitive data even in `os.log`

**Example**

```swift
// BAD
print("User bought \(quantity) shares at \(price)")

// GOOD
logger.info("Transaction recorded") // No values logged
```

**Debug Logging**

- If debug logging needed, use `#if DEBUG` and generic messages
- Never log production user data

______________________________________________________________________

### Secure Deletion

**Data Deletion**

- When user deletes asset/transaction/portfolio, SwiftData removes from database
- OS handles secure file deletion (SQLite journal, etc.)

**App Uninstall**

- Uninstalling app removes app sandbox (all data deleted)
- User data in iCloud sync persists (user must delete from iCloud separately)

**Future: "Erase All Data" Feature**

- Clear all SwiftData models
- Reset app to initial state
- Confirmation dialog to prevent accidental deletion

______________________________________________________________________

## Compliance and Regulations

### GDPR (General Data Protection Regulation)

**Applicability**

- If app used by EU users, GDPR may apply
- AssetFlow: No data collected by developer → minimal GDPR obligations
- User controls their data fully → compliant with data ownership principles

**GDPR-Ready**

- Right to access: User has full access to their data
- Right to erasure: User can delete data
- Right to portability: Export feature (future)
- Data minimization: No unnecessary data collected

______________________________________________________________________

### CCPA (California Consumer Privacy Act)

**Applicability**

- If app used by California residents
- AssetFlow: No data collection/sale → minimal CCPA obligations

**CCPA-Ready**

- No sale of personal information
- No data sharing with third parties
- User has full control and transparency

______________________________________________________________________

### Financial Regulations

**Not Applicable**

- AssetFlow is a personal tracking tool, not a financial service
- No banking, trading, or investment advice features
- User manually enters data (no institutional connections)
- Not subject to financial industry regulations (e.g., SOX, PCI-DSS)

**Disclaimers** (to include in app)

> AssetFlow is a personal financial tracking tool. It does not provide investment advice, tax advice, or financial planning services. Consult a qualified financial advisor for personalized guidance.

______________________________________________________________________

## Incident Response

### Security Vulnerability Discovery

**If Vulnerability Found**

1. **Assess Severity**

   - Critical: Data exposure, data loss risk
   - High: Potential for exploitation
   - Medium: Minor issues, limited impact
   - Low: Theoretical, hard to exploit

1. **Develop Fix**

   - Prioritize based on severity
   - Test thoroughly

1. **Release Update**

   - App Store update (fast review for security fixes)
   - Include clear release notes (without revealing exploit details)

1. **User Communication**

   - For critical issues: In-app notification or alert
   - Recommend immediate update

**Responsible Disclosure**

- If third-party reports vulnerability, acknowledge and respond promptly
- Credit reporter (if desired)
- Fix before public disclosure

______________________________________________________________________

### Data Breach (Unlikely for Local App)

**Scenario**: If iCloud sync used and Apple suffers breach (extremely unlikely)

**Response**

1. Monitor Apple security announcements
1. If breach confirmed, notify users (via app update or release notes)
1. Recommend changing iCloud password, enabling 2FA
1. Evaluate whether to continue iCloud sync feature

______________________________________________________________________

## User Security Best Practices

### Recommendations to Users

**Device Security**

- Enable device passcode/password (strong, unique)
- Enable Touch ID / Face ID (biometric lock)
- Enable FileVault (macOS)
- Keep OS updated (security patches)

**Backup Security**

- Enable encrypted backups (iTunes/Finder, Time Machine)
- Use iCloud with 2FA enabled

**App Usage**

- Keep AssetFlow updated (security fixes)
- Do not share device access with untrusted persons
- Regularly review and back up financial data (export feature)

**Export File Security**

- If exporting data (CSV, JSON), store export files securely
- Delete export files when no longer needed
- Do not share exports publicly (contain sensitive data)

______________________________________________________________________

## Future Security Enhancements

### Phase 4+

**Multi-Device Sync Security**

- End-to-end encryption for iCloud sync
- Conflict resolution without data loss
- Sync audit log (view sync history)

**Biometric Unlock** (Optional)

- Require Face ID/Touch ID to open app
- Optional feature, user preference
- Lock app after inactivity

**Export File Encryption**

- Encrypt CSV/JSON exports with password
- Use standard encryption (AES-256)

**API Key Security**

- Store third-party API keys in Keychain
- Rotate keys periodically
- Use least-privilege API permissions

**Security Audit**

- Periodic review of codebase for vulnerabilities
- Static analysis tools (already using SwiftLint)
- Penetration testing (if app gains network features)

______________________________________________________________________

## Security Checklist

### Development

- [ ] All financial data uses `Decimal` type
- [ ] No `print()` statements with sensitive data
- [ ] Input validation on all user inputs
- [ ] Business logic prevents invalid states
- [ ] SwiftLint checks pass (security rules)
- [ ] No hardcoded API keys or secrets
- [ ] Code signed with valid developer certificate

### Pre-Release

- [ ] App sandboxed (macOS)
- [ ] Hardened Runtime enabled (macOS)
- [ ] App Transport Security enforced (network features)
- [ ] Privacy disclosures accurate
- [ ] User-facing disclaimers included
- [ ] Security review completed

### Post-Release

- [ ] Monitor for security issues
- [ ] Respond to vulnerability reports
- [ ] Release security updates promptly
- [ ] Keep dependencies updated (SwiftData, SwiftUI, etc.)

______________________________________________________________________

## Privacy Nutrition Label (App Store)

Apple requires privacy "nutrition label" for App Store submissions.

**AssetFlow's Expected Label** (Phase 1-3)

**Data Not Collected**

- No data collected by this app

**Data Linked to You**

- None

**Data Used to Track You**

- None

**Phase 4+ (with network features)**

**Data Not Collected**

- Financial data: Not collected (stays local)
- Identifiers: Not collected

**Data Used for Functionality** (not linked to user)

- Usage Data: Asset symbols for price lookup (not tied to user identity)

______________________________________________________________________

## Conclusion

AssetFlow's **local-first, privacy-by-design architecture** inherently mitigates many security and privacy risks. By leveraging Apple platform security features and following secure coding practices, AssetFlow protects user financial data effectively.

**Key Principles**

- User data stays on their device (and their iCloud, if opted in)
- No third-party data sharing or collection
- Transparent about data handling
- User has full control and ownership

**Ongoing Commitment**

- Regular security reviews
- Prompt response to vulnerabilities
- User education on best practices
- Continuous improvement of security posture

______________________________________________________________________

## References

### Apple Security Documentation

- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Data Protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)

### Privacy Regulations

- [GDPR Overview](https://gdpr.eu/)
- [CCPA Overview](https://oag.ca.gov/privacy/ccpa)

### Best Practices

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Privacy Guidelines](https://developer.apple.com/app-store/user-privacy-and-data-use/)

______________________________________________________________________

**Document Status**: ✅ Initial framework complete

**Last Updated**: 2025-10-09

**Next Review**: When network features (API calls, iCloud sync) are implemented

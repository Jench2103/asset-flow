# Security and Privacy

## Preface

**Purpose of this Document**

This document outlines the security and privacy considerations for AssetFlow, a personal finance application handling sensitive financial data. It describes the measures taken to protect user data, ensure privacy, and maintain secure operation on macOS.

**Philosophy**

1. **Privacy by Design**: Minimal data collection, user owns all data
1. **Local-Only**: Data stays on user's device -- no network, no cloud, no APIs
1. **Platform Trust**: Leverage Apple's security infrastructure
1. **Transparency**: Clear communication about data handling
1. **User Control**: Users can export, delete, or back up their data

**Related Documentation**

- [Architecture.md](Architecture.md) - System architecture and data flow
- [DataModel.md](DataModel.md) - Data structures and relationships
- [APIDesign.md](APIDesign.md) - Backup/restore format and validation

______________________________________________________________________

## Threat Model

### Assets to Protect

**Sensitive Data**:

- Portfolio composition and asset values
- Snapshot history (reveals wealth trajectory over time)
- Category allocations and target allocations
- Cash flow operations (deposits, withdrawals)
- Backup files (contain all of the above)

**Sensitivity Level**: **High**

- Exposure could reveal user's wealth, investment strategy, and financial situation
- Not authentication credentials, but valuable for profiling

### Potential Threats

**Local Device Threats**:

1. **Physical Device Access**: Unauthorized person accesses unlocked Mac
1. **Device Theft**: Lost or stolen Mac
1. **Malware**: Malicious software on the device
1. **Backup Exposure**: Unencrypted backup files accessible to others

**Backup File Threats**:

5. **Unsecured Export Files**: ZIP backup files stored in unprotected locations
1. **Shared Storage**: Backup files on shared drives, cloud storage, or email

### Mitigations

**Device-Level Security** (Apple Platform Features):

1. **File System Encryption**: FileVault encrypts the entire disk
1. **App Sandbox**: macOS sandbox isolates app data from other apps
1. **Code Signing**: App signed by developer, ensures integrity
1. **Hardened Runtime**: Prevents code injection and memory tampering
1. **Gatekeeper**: macOS verifies signed apps before launch

**Application-Level Security**:

1. **No Network Access**: No data transmission of any kind -- no APIs, no telemetry, no analytics
1. **No API Keys**: No secrets to manage or leak
1. **SwiftData Encryption**: Leverages platform database encryption (FileVault)
1. **No Logging of Sensitive Data**: Financial values never logged to console
1. **Input Validation**: All user inputs validated before processing
1. **Secure Deletion**: SwiftData removes data when user requests

______________________________________________________________________

## Data Security

### Data Storage

**SwiftData Persistence**:

- **Location**: App sandbox directory (isolated from other apps)
- **Encryption**: Encrypted at rest when FileVault is enabled (recommended)

**No Network Storage**:

- No cloud sync, no iCloud, no remote servers
- All data resides exclusively on the user's Mac

### Backup File Security

**Export Format**: ZIP archive containing CSV files and a manifest.json.

**Security Characteristics**:

- Backup files are **not encrypted** by the application
- They contain all financial data in human-readable CSV format
- User is responsible for storing backup files securely

**Recommendations to Users**:

- Store backup files in an encrypted volume or directory
- Do not share backup files via unencrypted channels (email, public cloud)
- Delete old backup files when no longer needed
- Consider encrypting backup files with a third-party tool if storing on shared media

**Restore Security**:

- Restore operation validates file integrity before modifying data
- Validation includes CSV structure, column headers, and foreign key references
- If validation fails, no data is modified
- Restore requires explicit confirmation: "Restoring from backup will replace ALL existing data. This cannot be undone."

______________________________________________________________________

## Privacy

### Data Collection

**What Data is Collected**: None by the developer.

- All data is user-entered and stored locally
- No analytics, telemetry, or usage tracking
- No crash reporting sent to the developer

**What Data is NOT Collected**:

- No personal identifiers (name, email, phone)
- No usage patterns or behavior data
- No location data
- No network traffic (the app makes no network requests)

**Data Ownership**:

- User owns 100% of their data
- Data stored only on user's device
- No server-side storage by developer

### Data Usage

**Within the App**:

- Data used solely for app functionality (calculations, displays, charts)
- No secondary use (no ads, no profiling, no recommendations)

**With Third Parties**:

- **No third-party data sharing** -- the app has no network access
- No data sold or shared with any entity

### User Control

**Data Export**:

- User can export all data via the backup feature (ZIP archive)
- Enables backup and migration to other tools

**Data Deletion**:

- User can delete individual snapshots, assets, categories, and cash flow operations
- Uninstalling app removes all local data (app sandbox is deleted)

______________________________________________________________________

## Platform Security Features

### macOS Security

**App Sandbox**:

- Enabled (App Store requirement)
- Restricts file system access to app's container
- No network access entitlement needed (no network features)

**Hardened Runtime**:

- Enabled for distribution
- Prevents code injection, memory tampering
- Required for notarization

**Code Signing**:

- App signed with Developer ID
- Ensures integrity and verifies developer

**Gatekeeper**:

- macOS checks signed apps before launch
- Prevents running tampered or malicious apps

**FileVault**:

- Encrypts entire disk when enabled by user
- All SwiftData files encrypted at rest
- Strongly recommended for users storing financial data

______________________________________________________________________

## Secure Coding Practices

### Input Validation

**Financial Inputs**:

- Validate all user inputs (market values, amounts, dates)
- Use `Decimal` type (prevents floating-point injection risks)
- Reject invalid formats during CSV parsing
- Enforce uniqueness constraints (asset identity, snapshot dates, cash flow descriptions)

**CSV Import Validation**:

- Validate file encoding (UTF-8)
- Validate required columns exist
- Validate number formatting per row
- Detect duplicates within CSV and against existing data
- Block entire import if validation errors exist (no partial imports)

### No Sensitive Data Logging

**Prohibition**: Never log financial values, asset names, or portfolio data to console.

**SwiftLint Rule**: `print()` statements are prohibited.

```swift
// BAD
print("Portfolio value: \(totalValue)")

// GOOD
logger.info("Portfolio value calculated successfully")
```

### Secure Deletion

**Data Deletion**:

- When user deletes a snapshot, SwiftData removes all associated SnapshotAssetValues and CashFlowOperations (cascade)
- When user deletes an asset (if allowed), SwiftData removes all associated SnapshotAssetValues (cascade)
- OS handles secure file deletion at the SQLite level

**App Uninstall**:

- Uninstalling app removes app sandbox (all data deleted)
- Backup files stored outside the sandbox persist (user must delete manually)

______________________________________________________________________

## Compliance and Regulations

### GDPR (General Data Protection Regulation)

**Applicability**: Minimal obligations since no data is collected by the developer.

**GDPR-Ready**:

- Right to access: User has full access to their data
- Right to erasure: User can delete all data
- Right to portability: Backup export feature
- Data minimization: No unnecessary data collected

### CCPA (California Consumer Privacy Act)

**CCPA-Ready**:

- No sale of personal information
- No data sharing with third parties
- User has full control and transparency

### Financial Regulations

**Not Applicable**:

- AssetFlow is a personal tracking tool, not a financial service
- No banking, trading, or investment advice features
- Not subject to financial industry regulations

______________________________________________________________________

## Privacy Nutrition Label (App Store)

**Data Not Collected**: No data collected by this app.

**Data Linked to You**: None.

**Data Used to Track You**: None.

______________________________________________________________________

## Security Checklist

### Development

- [ ] All financial data uses `Decimal` type
- [ ] No `print()` statements with sensitive data
- [ ] Input validation on all user inputs
- [ ] Business logic prevents invalid states
- [ ] SwiftLint checks pass
- [ ] No hardcoded secrets (none needed -- no APIs)
- [ ] Code signed with valid developer certificate

### Pre-Release

- [ ] App sandboxed
- [ ] Hardened Runtime enabled
- [ ] No network entitlements
- [ ] Privacy disclosures accurate
- [ ] Backup/restore validation thoroughly tested

### User Recommendations

- [ ] Enable FileVault for disk encryption
- [ ] Keep macOS updated (security patches)
- [ ] Store backup files securely
- [ ] Delete old backup files when no longer needed
- [ ] Enable strong login password

______________________________________________________________________

## Incident Response

### Security Vulnerability Discovery

1. **Assess Severity** (Critical/High/Medium/Low)
1. **Develop Fix** (prioritize based on severity)
1. **Release Update** (App Store fast review for security fixes)
1. **User Communication** (release notes, in-app notification for critical issues)

______________________________________________________________________

## Conclusion

AssetFlow's **local-only, privacy-by-design architecture** inherently mitigates many security and privacy risks. With no network access, no external APIs, and no data collection, the primary security concerns are limited to local device protection and backup file security.

**Key Principles**:

- All data stays on the user's device
- No network communication of any kind
- No third-party data sharing or collection
- User has full control and ownership
- Backup files are the user's responsibility to secure

______________________________________________________________________

## References

### Apple Security Documentation

- [Apple Platform Security](https://support.apple.com/guide/security/welcome/web)
- [App Sandbox](https://developer.apple.com/documentation/security/app_sandbox)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)

### Privacy Regulations

- [GDPR Overview](https://gdpr.eu/)
- [CCPA Overview](https://oag.ca.gov/privacy/ccpa)

### Best Practices

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Privacy Guidelines](https://developer.apple.com/app-store/user-privacy-and-data-use/)

# Changelog

## [0.3.0](https://github.com/Jench2103/asset-flow/compare/v0.2.0...v0.3.0) (2026-02-21)

### Features

- **charts:** Upgrade asset detail sparkline to full line chart ([5d51754](https://github.com/Jench2103/asset-flow/commit/5d51754350f58b0f69d66def9a164d3f6dd98297))
- **dashboard:** Rebase cumulative TWR chart to 0% on period selection ([3406577](https://github.com/Jench2103/asset-flow/commit/34065774bda15122d7ccd34550350249b0f4d644))
- **ui:** Modernize UI patterns with native macOS conventions ([8a5c309](https://github.com/Jench2103/asset-flow/commit/8a5c3093a707e8bf34471a31bd57f98785937bf7))

### Bug Fixes

- **charts:** Pin axes and fix tooltip clipping in detail view charts ([d505c91](https://github.com/Jench2103/asset-flow/commit/d505c915c845c964a7ae4420472dc074eecd7c3b))
- **charts:** Pin Y-axis domain to prevent axis shift during hover ([c02d963](https://github.com/Jench2103/asset-flow/commit/c02d963a62a1fa47f4f8e713c831de00a7e2e372))
- **dashboard:** Add 0% origin point to TWR history for consistent rebasing ([44ad4ca](https://github.com/Jench2103/asset-flow/commit/44ad4ca0666fece4305060c64f719162746925e3))
- **i18n:** Add missing zh-Hant translations for empty state views ([1137cb9](https://github.com/Jench2103/asset-flow/commit/1137cb96d10c3e456e35d12fa962409773e934d1))
- **l10n:** Make CSV column names non-localizable in import view ([470ec97](https://github.com/Jench2103/asset-flow/commit/470ec97f16609baf4383730fa196bd099fb61a28))

## [0.2.0](https://github.com/Jench2103/asset-flow/compare/v0.1.0...v0.2.0) (2026-02-20)

### Features

- **import:** Add platform apply mode for CSV import ([af70a67](https://github.com/Jench2103/asset-flow/commit/af70a67d8141a0bd5481e13f634ffffdae115585))
- **ui:** Make sidebar always visible and non-collapsible ([275db37](https://github.com/Jench2103/asset-flow/commit/275db37ae892e676cb9ff45baa61b669adcb5e63))

### Bug Fixes

- **import:** Cache CSV file data to fix platform selection after file load ([5d8b1e6](https://github.com/Jench2103/asset-flow/commit/5d8b1e613cd3489ddec87f9489b44b9e527e5284))
- **import:** Improve CSV import reliability and UX ([#15](https://github.com/Jench2103/asset-flow/issues/15)) ([d58be4d](https://github.com/Jench2103/asset-flow/commit/d58be4d33de42ad2737ae2859efef93189f6ec11))
- **import:** Preserve excluded rows when platform or category changes ([13c9aef](https://github.com/Jench2103/asset-flow/commit/13c9aefa5292a1b9589225cf4e834c8a4764725b))
- **import:** Reset import form after successful CSV import ([5b80783](https://github.com/Jench2103/asset-flow/commit/5b807830542c614b7756a88dee912a3c66e4810c))

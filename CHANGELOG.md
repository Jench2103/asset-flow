# Changelog

## [0.4.0](https://github.com/Jench2103/asset-flow/compare/v0.3.0...v0.4.0) (2026-03-02)


### Features

* Add multi-currency support with exchange rate conversion ([#22](https://github.com/Jench2103/asset-flow/issues/22)) ([36b58f9](https://github.com/Jench2103/asset-flow/commit/36b58f99ad78abc34a99769703a81d2544e55d63))
* **asset:** Add converted value column and chart to asset detail view ([70ebf17](https://github.com/Jench2103/asset-flow/commit/70ebf17ee88de9c8a9da70172a0d6816977b953b))
* **assets:** Add inline value editing to asset detail history table ([144da63](https://github.com/Jench2103/asset-flow/commit/144da63873e58d4582470e02d0af3842093a7807))
* **categories:** Add configurable category order via drag-and-drop ([687066a](https://github.com/Jench2103/asset-flow/commit/687066a5e1c781192817091ef36623328e380ba6))
* **chart:** Add dynamic multi-column legend to pie chart ([568cf75](https://github.com/Jench2103/asset-flow/commit/568cf7534e0a63ccfadcfb7452ce243635dfa08c))
* **dashboard:** Replace 14-day backward lookback with bidirectional closest-snapshot matching ([9135f6f](https://github.com/Jench2103/asset-flow/commit/9135f6fbdd11fcdf393ce725b621c85d1af77b84))
* **dashboard:** Smooth pie chart angle animation and improved color palette ([76a0f67](https://github.com/Jench2103/asset-flow/commit/76a0f6729677a212192ebb1c608b14a9c78ca4df))
* **import:** Add currency column support with validation and auth-aware popovers ([852d887](https://github.com/Jench2103/asset-flow/commit/852d88793d028ce6c371a52b2600fa5694357608))
* **import:** Move validation to per-row errors and add category apply mode ([e803c30](https://github.com/Jench2103/asset-flow/commit/e803c30cf5c0431a3b428572d2392ef04ab3cbaf))
* **security:** Add lock-aware hover modifiers to prevent data leakage ([107eecb](https://github.com/Jench2103/asset-flow/commit/107eecbe9acdef510605552af9e07f25beacf187))
* **security:** Add optional app lock with Touch ID and system password ([833de3b](https://github.com/Jench2103/asset-flow/commit/833de3b8b239861e74cd710f6e66df53c4a6ffc9))
* **ui:** Add exchange rate display section to snapshot detail ([399355e](https://github.com/Jench2103/asset-flow/commit/399355e8bda6b2f99c5edbd261986880de1ed3b4))
* **ui:** Add platform list reordering and category deviation help messages ([5a78c9f](https://github.com/Jench2103/asset-flow/commit/5a78c9f3c735956808423925e2b5c5d970aeb92f))
* **ui:** Add shared animation constants with Reduce Motion support ([cc34621](https://github.com/Jench2103/asset-flow/commit/cc34621a6affe60d81cef97cdfdc619e29b3dff6))


### Bug Fixes

* **asset:** Initialize picker caches in init to prevent invalid selection warnings ([10b9816](https://github.com/Jench2103/asset-flow/commit/10b98161da40783791e69d1e09d1bc0ebc74ad6d))
* **dashboard:** Prevent stat card labels from wrapping or truncating ([daa0c6e](https://github.com/Jench2103/asset-flow/commit/daa0c6e9bd92b54d13a74bf0174bf79a7753036b))
* **l10n:** Add missing zh-Hant translations for charts, toolbars, and buttons ([7fdc4d7](https://github.com/Jench2103/asset-flow/commit/7fdc4d78fe4a70148abd0784959ab802f79ac93c))
* **l10n:** Localize privacy disclaimer in native About panel ([aefc6c8](https://github.com/Jench2103/asset-flow/commit/aefc6c81a3fffd4efb55dca36b9ef64cc7876c0c))
* **reactivity:** Refresh list views after detail view edits ([3ac18d3](https://github.com/Jench2103/asset-flow/commit/3ac18d3cea2813f886a7b6b0ce64d728719c5c40))
* **tables:** Add visible column resize handles to detail view tables ([ec51c14](https://github.com/Jench2103/asset-flow/commit/ec51c140b5dbfffe1ad93f9303f11e3e4a354e82))
* **test:** Replace flaky Task.sleep with deterministic Task.value await ([e1477c8](https://github.com/Jench2103/asset-flow/commit/e1477c8a1588488b6d0ef3c30a4971d0d4ea7f85))

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

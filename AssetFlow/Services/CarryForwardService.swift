//
//  CarryForwardService.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation

/// Represents an asset value in a composite snapshot view, indicating whether
/// the value is directly recorded or carried forward from a prior snapshot.
struct CompositeAssetValue {
  let asset: Asset
  let marketValue: Decimal
  let isCarriedForward: Bool
  let sourceSnapshotDate: Date?
}

/// Carry-forward resolution service.
///
/// Computes composite snapshot views by merging directly-recorded asset values
/// with carried-forward values from prior snapshots for platforms not present
/// in the current snapshot.
///
/// Carry-forward operates at the **platform level** (SPEC Section 2):
/// - If a platform appears in the current snapshot (has at least one direct
///   SnapshotAssetValue), only those direct values represent that platform.
/// - For platforms NOT in the current snapshot, all assets from the most recent
///   prior snapshot containing that platform are carried forward.
///
/// All methods operate on pre-fetched data to avoid N+1 queries (SPEC Section 14).
enum CarryForwardService {

  /// Returns all composite asset values for a snapshot, including carry-forward.
  ///
  /// - Parameters:
  ///   - snapshot: The target snapshot to compute composite values for.
  ///   - allSnapshots: All snapshots sorted by date (ascending).
  ///   - allAssetValues: All pre-fetched SnapshotAssetValues across all snapshots.
  /// - Returns: Array of composite asset values (direct + carried forward).
  static func compositeValues(
    for snapshot: Snapshot,
    allSnapshots: [Snapshot],
    allAssetValues: [SnapshotAssetValue]
  ) -> [CompositeAssetValue] {
    // Group asset values by snapshot (using persistent model ID for reliable matching)
    let valuesBySnapshot = Dictionary(grouping: allAssetValues) { $0.snapshot }

    let directValues = valuesBySnapshot[snapshot] ?? []

    // Determine which platforms are directly present in this snapshot
    let directPlatforms = Set(
      directValues.compactMap { $0.asset?.platform }
    )

    // Start with direct values
    var result: [CompositeAssetValue] = directValues.compactMap { sav in
      guard let asset = sav.asset else { return nil }
      return CompositeAssetValue(
        asset: asset,
        marketValue: sav.marketValue,
        isCarriedForward: false,
        sourceSnapshotDate: nil
      )
    }

    // Find prior snapshots (those with date before current snapshot's date)
    let priorSnapshots =
      allSnapshots
      .filter { $0.date < snapshot.date }
      .sorted { $0.date > $1.date }  // Most recent first

    // For each platform NOT in the current snapshot, find its most recent values
    var carriedPlatforms = Set<String>()

    for priorSnapshot in priorSnapshots {
      let priorValues = valuesBySnapshot[priorSnapshot] ?? []

      for sav in priorValues {
        guard let asset = sav.asset else { continue }
        let platform = asset.platform

        // Skip if this platform is directly present in the current snapshot
        guard !directPlatforms.contains(platform) else { continue }

        // Skip if we already carried forward this platform from a more recent snapshot
        guard !carriedPlatforms.contains(platform) else { continue }

        result.append(
          CompositeAssetValue(
            asset: asset,
            marketValue: sav.marketValue,
            isCarriedForward: true,
            sourceSnapshotDate: priorSnapshot.date
          )
        )
      }

      // Mark all platforms in this prior snapshot as carried (even if some assets
      // were already carried from a more recent snapshot for the same platform)
      let priorPlatforms = Set(priorValues.compactMap { $0.asset?.platform })
      for platform in priorPlatforms where !directPlatforms.contains(platform) {
        carriedPlatforms.insert(platform)
      }
    }

    return result
  }

  /// Returns the composite total portfolio value for a snapshot.
  ///
  /// - Parameters:
  ///   - snapshot: The target snapshot.
  ///   - allSnapshots: All snapshots sorted by date (ascending).
  ///   - allAssetValues: All pre-fetched SnapshotAssetValues across all snapshots.
  /// - Returns: Sum of all composite asset values (direct + carried forward).
  static func compositeTotalValue(
    for snapshot: Snapshot,
    allSnapshots: [Snapshot],
    allAssetValues: [SnapshotAssetValue]
  ) -> Decimal {
    compositeValues(for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)
      .reduce(Decimal(0)) { $0 + $1.marketValue }
  }
}

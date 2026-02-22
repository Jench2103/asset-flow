//
//  SchemaVersioning.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import SwiftData

enum SchemaV1: VersionedSchema {
  static var versionIdentifier = Schema.Version(1, 0, 0)

  static var models: [any PersistentModel.Type] {
    [
      Category.self,
      Asset.self,
      Snapshot.self,
      SnapshotAssetValue.self,
      CashFlowOperation.self,
      ExchangeRate.self,
    ]
  }
}

enum AssetFlowMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self]
  }

  static var stages: [MigrationStage] {
    []
  }
}

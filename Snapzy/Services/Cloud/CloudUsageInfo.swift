//
//  CloudUsageInfo.swift
//  Snapzy
//
//  Value type for cloud bucket usage statistics
//

import Foundation

/// Snapshot of cloud bucket usage data
struct CloudUsageInfo: Codable, Equatable {
  let providerType: CloudProviderType
  let totalStorageBytes: Int64
  let objectCount: Int
  /// Legacy lifecycle field retained for cached usage compatibility; managed uploads do not query it.
  let lifecycleRuleDays: Int?
  let fetchedAt: Date

  /// Human-readable storage size
  var formattedStorage: String {
    ByteCountFormatter.string(fromByteCount: totalStorageBytes, countStyle: .file)
  }
}

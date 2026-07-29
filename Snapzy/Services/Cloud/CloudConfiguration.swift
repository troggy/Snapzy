//
//  CloudConfiguration.swift
//  Snapzy
//
//  Data model for cloud storage configuration and expire time options
//

import Foundation

// MARK: - Cloud Expire Time

/// Expiration time options for uploaded files.
/// Aligned with AWS S3 / Cloudflare R2 lifecycle rule granularity (days).
enum CloudExpireTime: String, Codable, CaseIterable {
  case day1 = "1d"
  case day3 = "3d"
  case day7 = "7d"
  case day14 = "14d"
  case day30 = "30d"
  case day60 = "60d"
  case day90 = "90d"
  case permanent = "permanent"

  var displayName: String {
    switch self {
    case .day1: return L10n.CloudExpire.day1
    case .day3: return L10n.CloudExpire.day3
    case .day7: return L10n.CloudExpire.day7
    case .day14: return L10n.CloudExpire.day14
    case .day30: return L10n.CloudExpire.day30
    case .day60: return L10n.CloudExpire.day60
    case .day90: return L10n.CloudExpire.day90
    case .permanent: return L10n.CloudExpire.permanent
    }
  }

  /// Number of days for S3/R2 lifecycle Expiration.Days, nil for permanent
  var days: Int? {
    switch self {
    case .day1: return 1
    case .day3: return 3
    case .day7: return 7
    case .day14: return 14
    case .day30: return 30
    case .day60: return 60
    case .day90: return 90
    case .permanent: return nil
    }
  }

  /// Duration in seconds, nil for permanent. Used for local isExpired check and Cache-Control.
  var seconds: Int? {
    guard let d = days else { return nil }
    return d * 86400
  }

  var isPermanent: Bool { self == .permanent }

  /// Decode legacy values (15m, 30m, 1h, etc.) by mapping to nearest day-based option
  init(legacyRawValue: String) {
    switch legacyRawValue {
    case "15m", "30m", "1h", "2h", "3h", "5h", "8h", "12h":
      self = .day1
    case "5d":
      self = .day7
    case "15d":
      self = .day14
    case "24d":
      self = .day30
    default:
      self = CloudExpireTime(rawValue: legacyRawValue) ?? .day7
    }
  }
}

// MARK: - Cloud Configuration

/// Non-sensitive cloud storage configuration stored in UserDefaults
struct CloudConfiguration: Codable, Equatable {
  let providerType: CloudProviderType
  let bucket: String
  let region: String
  let endpoint: String?
  let customDomain: String?
  /// Company-assigned identifier that scopes this installation's managed objects.
  let storageID: String
  let expireTime: CloudExpireTime

  init(
    providerType: CloudProviderType,
    bucket: String,
    region: String,
    endpoint: String?,
    customDomain: String?,
    storageID: String = "",
    expireTime: CloudExpireTime
  ) {
    self.providerType = providerType
    self.bucket = bucket
    self.region = region
    self.endpoint = endpoint
    self.customDomain = customDomain
    self.storageID = storageID
    self.expireTime = expireTime
  }

  private enum CodingKeys: String, CodingKey {
    case providerType
    case bucket
    case region
    case endpoint
    case customDomain
    case storageID
    case expireTime
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    providerType = try container.decode(CloudProviderType.self, forKey: .providerType)
    bucket = try container.decode(String.self, forKey: .bucket)
    region = try container.decode(String.self, forKey: .region)
    endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint)
    customDomain = try container.decodeIfPresent(String.self, forKey: .customDomain)
    // Archives created before managed storage used no storage ID.
    storageID = try container.decodeIfPresent(String.self, forKey: .storageID) ?? ""
    expireTime = try container.decode(CloudExpireTime.self, forKey: .expireTime)
  }

  var isStorageIDValid: Bool {
    Self.isValidStorageID(storageID)
  }

  static func isValidStorageID(_ value: String) -> Bool {
    value.count == 32 && value.allSatisfy { "0123456789abcdef".contains($0) }
  }

  /// Validate that required fields are present
  var isValid: Bool {
    switch providerType {
    case .awsS3:
      return !bucket.trimmingCharacters(in: .whitespaces).isEmpty
        && !region.trimmingCharacters(in: .whitespaces).isEmpty
        && isStorageIDValid
    case .cloudflareR2:
      return !bucket.trimmingCharacters(in: .whitespaces).isEmpty
        && !(endpoint ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        && isStorageIDValid
    case .googleDrive:
      // googleDrive doesn't require bucket/region/endpoint fields to be validated here,
      // and default folder name "Snapzy" is used if bucket is empty.
      return true
    }
  }
}

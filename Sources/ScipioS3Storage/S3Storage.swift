import Foundation
import ScipioKit

public struct S3StorageConfig {
    public var accessKeyID: String
    public var secretAccessKey: String
    public var bucket: String
    public var region: String
    public var endpoint: URL

    public init(accessKeyID: String, secretAccessKey: String, bucket: String, region: String, endpoint: URL) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.bucket = bucket
        self.region = region
        self.endpoint = endpoint
    }
}

public struct S3Storage: CacheStorage {


    private let storageClient: ObjectStorageClient

    public init(config: S3StorageConfig) async throws {
        self.storageClient = try ObjectStorageClient(storageConfig: config)
    }

    public func existsValidCache(for cacheKey: ScipioKit.CacheKey) async -> Bool {
        return false
    }

    public func fetchArtifacts(for cacheKey: ScipioKit.CacheKey, to destinationDir: URL) async throws {
        
    }

    public func cacheFramework(_ frameworkPath: URL, for cacheKey: ScipioKit.CacheKey) async {
        do {
            try await storageClient.putObject()
        } catch {
            print(error)
        }
    }
}

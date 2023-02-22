import Foundation
import ScipioKit
import ClientRuntime

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
    private let storagePrefix: String?
    private let storageClient: ObjectStorageClient

    public init(config: S3StorageConfig, storagePrefix: String? = nil) async throws {
        self.storageClient = try ObjectStorageClient(storageConfig: config)
        self.storagePrefix = storagePrefix
    }

    public func existsValidCache(for cacheKey: ScipioKit.CacheKey) async throws -> Bool {
        let objectStorageKey = try constructObjectStorageKey(from: cacheKey)
        do {
            return try await storageClient.isExistObject(at: objectStorageKey)
        } catch {
            throw error
        }
    }

    public func fetchArtifacts(for cacheKey: ScipioKit.CacheKey, to destinationDir: URL) async throws {

    }

    public func cacheFramework(_ frameworkPath: URL, for cacheKey: ScipioKit.CacheKey) async throws {
        let compressor = Compressor()
        let stream = try compressor.compress(frameworkPath)
        let objectStorageKey = try constructObjectStorageKey(from: cacheKey)
        try await storageClient.putObject(stream, at: objectStorageKey)
    }

    private func constructObjectStorageKey(from cacheKey: CacheKey) throws -> String {
        let frameworkName = cacheKey.targetName
        let checksum = try cacheKey.calculateChecksum()
        let archiveName = "\(checksum).aar"
        return [storagePrefix, frameworkName, archiveName]
            .compactMap { $0 }
            .joined(separator: "/")
    }
}

import Foundation
import CacheStorage
import struct UniformTypeIdentifiers.UTType

public actor S3FrameworkStorage: FrameworkCacheStorage {
    private let storagePrefix: String?
    private let storageClient: any ObjectStorageClient
    private let compressor = Compressor()

    public init(config: S3StorageConfig, storagePrefix: String? = nil) throws {
        self.storageClient = switch config {
        case .publicURL(let endpoint, let bucket): PublicURLObjectStorageClient(endpoint: endpoint, bucket: bucket)
        case .authorized(let authorizedConfiguration): APIObjectStorageClient(authorizedConfiguration)
        }
        self.storagePrefix = storagePrefix
    }

    public func existsValidCache(for cacheKey: some CacheKey) async throws -> Bool {
        let objectStorageKey = try constructObjectStorageKey(from: cacheKey)
        return try await storageClient.isExistObject(at: objectStorageKey)
    }

    public func fetchArtifacts(for cacheKey: some CacheKey, to destinationDir: URL) async throws {
        let objectStorageKey = try constructObjectStorageKey(from: cacheKey)
        let archiveData = try await storageClient.fetchObject(at: objectStorageKey)
        let destinationPath = destinationDir.appendingPathComponent(cacheKey.frameworkName)
        try compressor.extract(archiveData, to: destinationPath)
    }

    public func cacheFramework(_ frameworkPath: URL, for cacheKey: some CacheKey) async throws {
        let data = try compressor.compress(frameworkPath)
        let objectStorageKey = try constructObjectStorageKey(from: cacheKey)
        try await storageClient.putObject(data, at: objectStorageKey)
    }

    private func constructObjectStorageKey(from cacheKey: some CacheKey) throws -> String {
        let frameworkName = cacheKey.targetName
        let checksum = try cacheKey.calculateChecksum()
        let archiveName = "\(checksum).aar"
        return [storagePrefix, frameworkName, archiveName]
            .compactMap { $0 }
            .joined(separator: "/")
    }
}

@available(*, deprecated, renamed: "S3FrameworkStorage")
public typealias S3Storage = S3FrameworkStorage

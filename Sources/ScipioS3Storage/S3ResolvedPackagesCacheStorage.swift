import Foundation
import CacheStorage

public actor S3ResolvedPackagesStorage: ResolvedPackagesCacheStorage {
    private let jsonDecoder = JSONDecoder()
    private let jsonEncoder = JSONEncoder()

    private let storageClient: any ObjectStorageClient
    private let fileManager: FileManager = .default
    private let storagePrefix: String?

    public init(
        config: S3StorageConfig,
        storagePrefix: String? = nil,
        timeout: TimeAmount? = nil
    ) throws {
        self.storagePrefix = storagePrefix
        self.storageClient = switch config {
        case .publicURL(let endpoint, let bucket): PublicURLObjectStorageClient(endpoint: endpoint, bucket: bucket, timeout: timeout)
        case .authorized(let authorizedConfiguration): APIObjectStorageClient(authorizedConfiguration, timeout: timeout)
        }
    }

    public func fetchResolvedPackages(for originHash: String) async throws -> [ResolvedPackage] {
        let objectStorageKey = constructObjectStorageKey(from: originHash)
        let archiveData = try await storageClient.fetchObject(at: objectStorageKey)
        return try jsonDecoder.decode([ResolvedPackage].self, from: archiveData)
    }

    public func cacheResolvedPackages(_ resolvedPackages: [ResolvedPackage], for originHash: String) async throws {
        let data = try jsonEncoder.encode(resolvedPackages)
        let objectStorageKey = constructObjectStorageKey(from: originHash)
        try await storageClient.putObject(data, at: objectStorageKey)
    }

    public func existsValidCache(for originHash: String) async throws -> Bool {
        let objectStorageKey = constructObjectStorageKey(from: originHash)
        return try await storageClient.isExistObject(at: objectStorageKey)
    }

    private func constructObjectStorageKey(from originHash: String) -> String {
        [storagePrefix, originHash].compactMap { $0 }.joined()
    }
}

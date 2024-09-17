import Foundation
import ScipioStorage

public enum S3StorageConfig: Sendable {
    /// A configuration which requires authentication.
    case authorized(AuthorizedConfiguration)

    /// A configuration for a public storage.
    case publicURL(endpoint: URL, bucket: String)
}

public struct AuthorizedConfiguration: Sendable {
    /// A bucket name
    public var bucket: String

    /// A region of the S3 bucket
    public var region: String

    /// An endpoint to the S3.
    /// When `nil` is passed, the url is guessed according to the given region.
    public var endpoint: URL?

    /// A boolean value indicating an object should be published or not when it's put.
    public var shouldPublishObject: Bool

    /// An access key.
    public var accessKeyID: String

    /// A secret access key
    public var secretAccessKey: String

    public init(
        bucket: String,
        region: String,
        endpoint: URL?,
        shouldPublishObject: Bool,
        accessKeyID: String,
        secretAccessKey: String
    ) {
        self.region = region
        self.bucket = bucket
        self.endpoint = endpoint
        self.shouldPublishObject = shouldPublishObject
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
    }
}

public actor S3Storage: CacheStorage {
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
        do {
            return try await storageClient.isExistObject(at: objectStorageKey)
        } catch {
            throw error
        }
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

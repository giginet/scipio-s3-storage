import Foundation
import SotoCore
import AsyncHTTPClient

protocol ObjectStorageClient: Sendable {
    func putObject(_ data: Data, at key: String) async throws
    func isExistObject(at key: String) async throws -> Bool
    func fetchObject(at key: String) async throws -> Data
}

actor APIObjectStorageClient: ObjectStorageClient {
    private let awsClient: AWSClient
    private let client: S3
    private let config: AuthorizedConfiguration

    enum Error: LocalizedError {
        case emptyObject

        var errorDescription: String? {
            switch self {
            case .emptyObject:
                return "No object is found"
            }
        }
    }

    init(_ config: AuthorizedConfiguration, timeout: TimeAmount?) {
        self.awsClient = AWSClient(
            credentialProvider: .static(
                accessKeyId: config.accessKeyID,
                secretAccessKey: config.secretAccessKey
            )
        )
        let endpointURL: URL? = switch config.endpoint {
        case .awsDefault: nil
        case .custom(let url): url
        }
        self.client = S3(
            client: awsClient,
            region: .init(awsRegionName: config.region),
            endpoint: endpointURL?.absoluteString,
            timeout: timeout
        )
        self.config = config
    }

    deinit {
        try? awsClient.syncShutdown()
    }

    func putObject(_ data: Data, at key: String) async throws {
        let acl: S3.ObjectCannedACL = config.shouldPublishObject ? .publicRead : .authenticatedRead
        let putObjectRequest = S3.PutObjectRequest(
            acl: acl,
            body: AWSHTTPBody(bytes: data),
            bucket: config.bucket,
            key: key
        )
        _ = try await client.putObject(putObjectRequest)
    }

    func isExistObject(at key: String) async throws -> Bool {
        let headObjectRequest = S3.HeadObjectRequest(
            bucket: config.bucket,
            key: key
        )
        do {
            _ = try await client.headObject(headObjectRequest)
            return true
        } catch let error as S3ErrorType where error == .notFound {
            return false
        }
    }

    func fetchObject(at key: String) async throws -> Data {
        let getObjectRequest = S3.GetObjectRequest(
            bucket: config.bucket,
            key: key
        )
        let response = try await client.getObject(getObjectRequest)
        let byteBuffer = try await response.body.collect(upTo: .max)
        let data = Data(buffer: byteBuffer)
        guard !data.isEmpty else {
            throw Error.emptyObject
        }
        return data
    }
}

struct PublicURLObjectStorageClient: ObjectStorageClient {
    private let endpoint: URL
    private let bucket: String
    private let httpClient: URLSession

    enum Error: LocalizedError {
        case putObjectIsNotSupported
        case unableToFetchObject(String)

        var errorDescription: String? {
            switch self {
            case .putObjectIsNotSupported:
                return "putObject requires authentication"
            case .unableToFetchObject(let key):
                return """
                Unable to fetch object for \"\(key)\".
                Object may not exist or not be public
                """
            }
        }
    }

    init(endpoint: URL, bucket: String, timeout: TimeAmount?) {
        let configuration = URLSessionConfiguration.default
        if let timeout {
            configuration.timeoutIntervalForRequest = Double(timeout.nanoseconds) / 1_000_000_000
        }

        self.endpoint = endpoint
        self.bucket = bucket
        self.httpClient = URLSession(configuration: configuration)
    }

    func putObject(_ data: Data, at key: String) async throws {
        throw Error.putObjectIsNotSupported
    }

    func isExistObject(at key: String) async throws -> Bool {
        let url = constructPublicURL(of: key)
        let request = {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            return request
        }()
        let (_, httpResponse) = try await httpClient.data(for: request)

        guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return false
        }
        return httpResponse.statusCode == 200
    }

    func fetchObject(at key: String) async throws -> Data {
        let url = constructPublicURL(of: key)
        let request = URLRequest(url: url)
        let (data, httpResponse) = try await httpClient.data(for: request)

        // Public URL returns 403 when object is not found
        guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw Error.unableToFetchObject(key)
        }
        return data
    }

    private func constructPublicURL(of key: String) -> URL {
        endpoint.appendingPathComponent(bucket)
            .appendingPathComponent(key)
    }
}

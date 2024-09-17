import Foundation
import SotoCore

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

    init(_ config: AuthorizedConfiguration) {
        self.awsClient = AWSClient(
            credentialProvider: .static(
                accessKeyId: config.accessKeyID,
                secretAccessKey: config.secretAccessKey
            ),
            httpClientProvider: .createNew
        )
        self.client = S3(
            client: awsClient,
            region: .init(awsRegionName: config.region),
            endpoint: config.endpoint?.absoluteString
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
            body: .byteBuffer(ByteBuffer(data: data)),
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
        guard let data = response.body?.asData() else {
            throw Error.emptyObject
        }
        return data
    }
}

struct PublicURLObjectStorageClient: ObjectStorageClient {
    private let endpoint: URL
    private let bucket: String
    private let httpClient: URLSession = .shared

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

    init(endpoint: URL, bucket: String) {
        self.endpoint = endpoint
        self.bucket = bucket
    }

    func putObject(_ data: Data, at key: String) async throws {
        throw Error.putObjectIsNotSupported
    }

    func isExistObject(at key: String) async throws -> Bool {
        let url = try constructPublicURL(of: key)
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
        let url = try constructPublicURL(of: key)
        let request = URLRequest(url: url)
        let (data, httpResponse) = try await httpClient.data(for: request)

        // Public URL returns 403 when object is not found
        guard let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw Error.unableToFetchObject(key)
        }
        return data
    }

    private func constructPublicURL(of key: String) throws -> URL {
        endpoint.appendingPathComponent(bucket)
            .appendingPathComponent(key)
    }
}

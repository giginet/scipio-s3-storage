import Foundation
import AWSS3
import ClientRuntime
import AWSClientRuntime

protocol ObjectStorageClient {
    init(storageConfig: S3StorageConfig) throws

    func putObject(_ stream: ByteStream, at key: String) async throws
    func isExistObject(at key: String) async throws -> Bool
    func fetchObject(at key: String) async throws -> Data
}

struct APIObjectStorageClient: ObjectStorageClient {
    private let client: S3Client
    private let storageConfig: S3StorageConfig

    enum Error: LocalizedError {
        case emptyObject

        var errorDescription: String? {
            switch self {
            case .emptyObject:
                return "No object is found"
            }
        }
    }

    init(storageConfig: S3StorageConfig) throws {
        switch storageConfig.authenticationMode {
        case .authorized(let accessKeyID, let secretAccessKey):
            var defaultConfig = try DefaultSDKRuntimeConfiguration("S3Client",
                                                                   clientLogMode: .requestAndResponse
            )
            defaultConfig.endpoint = storageConfig.endpoint.absoluteString
            let credentialsProvider = try AWSCredentialsProvider.fromStatic(
                AWSCredentialsProviderStaticConfig(
                    accessKey: accessKeyID,
                    secret: secretAccessKey
                )
            )
            let s3Config = try S3Client.S3ClientConfiguration(
                credentialsProvider: credentialsProvider,
                endpoint: storageConfig.endpoint.absoluteString,
                forcePathStyle: true,
                region: storageConfig.region,
                runtimeConfig: defaultConfig
            )
            self.client = AWSS3.S3Client(config: s3Config)
        case .usePublicURL:
            fatalError("Invalid authorizationMode")
        }
        self.storageConfig = storageConfig
    }

    func putObject(_ stream: ByteStream, at key: String) async throws {
        let putObjectInput = PutObjectInput(
            acl: .publicRead,
            body: stream,
            bucket: storageConfig.bucket,
            key: key
        )
        _ = try await client.putObject(input: putObjectInput)
    }

    func isExistObject(at key: String) async throws -> Bool {
        let headObjectInput = HeadObjectInput(
            bucket: storageConfig.bucket,
            key: key
        )
        do {
            _ = try await client.headObject(input: headObjectInput)
        } catch {
            guard let httpResponse = error.httpResponse, httpResponse.statusCode == .notFound else {
                throw error
            }
            return false
        }
        return true
    }

    func fetchObject(at key: String) async throws -> Data {
        let getObjectInput = GetObjectInput(
            bucket: storageConfig.bucket,
            key: key
        )
        let response = try await client.getObject(input: getObjectInput)
        guard let body = response.body else {
            throw Error.emptyObject
        }
        return body.toBytes().getData()
    }
}

struct PublicURLObjectStorageClient: ObjectStorageClient {
    private let storageConfig: S3StorageConfig
    private let httpClient: URLSession = .shared

    enum Error: LocalizedError {
        case putObjectIsNotSupported
        case objectIsNotFound(String)

        var errorDescription: String? {
            switch self {
            case .putObjectIsNotSupported:
                return "putObject requires authentication"
            case .objectIsNotFound(let key):
                return "Any object for \"\(key)\" is not found"
            }
        }
    }

    init(storageConfig: S3StorageConfig) throws {
        self.storageConfig = storageConfig
    }

    func putObject(_ stream: ByteStream, at key: String) async throws {
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

        guard let httpResponse = httpResponse as? HTTPURLResponse else {
            throw Error.objectIsNotFound(key)
        }
        return data
    }

    private func constructPublicURL(of key: String) -> URL {
        storageConfig.endpoint
            .appendingPathComponent(storageConfig.bucket)
            .appendingPathComponent(key)
    }
}

extension Error {
    fileprivate var httpResponse: HttpResponse? {
        if let clientError = self as? SdkError<AWSS3.HeadObjectOutputError>,
           case .client(let clientError, _) = clientError,
           case .retryError(let retryError) = clientError,
           let innerClientError = retryError as? SdkError<AWSS3.HeadObjectOutputError> {
            switch innerClientError {
            case .client(_, let response):
                return response
            case .service(_, let response):
                return response
            case .unknown:
                return nil
            }
        }
        return nil
    }
}

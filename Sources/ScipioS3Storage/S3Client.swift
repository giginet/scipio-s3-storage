import Foundation
import AWSS3
import ClientRuntime
import AWSClientRuntime

struct ObjectStorageClient {
    private let client: S3Client
    private let storageConfig: S3StorageConfig

    enum Error: LocalizedError {
        case emptyObject
    }

    init(storageConfig: S3StorageConfig) throws {
        var defaultConfig = try DefaultSDKRuntimeConfiguration("S3Client",
                                                               clientLogMode: .requestAndResponse
        )
        defaultConfig.endpoint = storageConfig.endpoint.absoluteString
        let credentialsProvider = try AWSCredentialsProvider.fromStatic(
            AWSCredentialsProviderStaticConfig(
                accessKey: storageConfig.accessKeyID,
                secret: storageConfig.secretAccessKey
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
        self.storageConfig = storageConfig
    }

    func putObject(_ stream: ByteStream, at key: String) async throws {
        let putObjectInput = PutObjectInput(
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

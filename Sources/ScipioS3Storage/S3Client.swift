import Foundation
import AWSS3
import ClientRuntime
import AWSClientRuntime

struct ObjectStorageClient {
    private let client: S3Client
    private let storageConfig: S3StorageConfig

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
        let response = try await client.putObject(input: putObjectInput)
        print(response.debugDescription)
    }
}

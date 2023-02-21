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

    func putObject() async throws {
        let data = "hello".data(using: .utf8)!
        let dataStream = ByteStream.from(data: data)
        let putObjectInput = PutObjectInput(
            body: dataStream,
            bucket: storageConfig.bucket,
            key: "test"
        )
        let response = try await client.putObject(input: putObjectInput)
        print(response.debugDescription)
    }
}

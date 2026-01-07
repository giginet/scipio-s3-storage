import Foundation

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
    public var endpoint: Endpoint

    /// A boolean value indicating an object should be published or not when it's put.
    public var shouldPublishObject: Bool

    /// An access key.
    public var accessKeyID: String

    /// A secret access key
    public var secretAccessKey: String

    /// Makes a configuration.
    /// - Parameters:
    ///   - bucket: A bucket name
    ///   - region: A region of the S3 bucket
    ///   - endpoint: An endpoint to the S3.
    ///   - shouldPublishObject: A boolean value indicating an object should be published or not when it's put.
    ///   - accessKeyID: An access key.
    ///   - secretAccessKey: A secret access key
    public init(
        bucket: String,
        region: String,
        endpoint: Endpoint = .awsDefault,
        shouldPublishObject: Bool = false,
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

extension AuthorizedConfiguration {
    public enum Endpoint: Sendable {
        /// A case indicating default URL of AWS. The url is guessed according to the given region.
        case awsDefault

        /// A case indicating custom URL.
        case custom(URL)
    }
}

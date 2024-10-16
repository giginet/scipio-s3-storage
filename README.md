# ScipioS3Storage

[Scipio](https://github.com/giginet/Scipio) cache storage backend for AWS S3.

## Usage

`scipio` CLI doesn't provide a way to set custom cache storage backend.

You have to prepare build script using `ScipioKit`.

```swift
import ScipioKit
import ScipioS3Storage

// Define S3 Storage settings
let config = AuthorizedConfiguration(
    bucket: "my-bucket",
    region: "ap-northeast-1",
    accessKeyID: "AWS_ACCESS_KEY_ID",
    secretAccessKey: "AWS_SECRET_ACCESS_KEY"
)

// Instantiate S3Storage
let s3Storage = try S3Storage(config: .authorized(config))

// Define Scipio Runner options
let options = Runner.Options(
    baseBuildOptions: .init(
        buildConfiguration: .release,
        isSimulatorSupported: false,
        isDebugSymbolsEmbedded: false,
        frameworkType: .static,
        extraBuildParameters: nil,
        enableLibraryEvolution: false
    ),
    buildOptionsMatrix: [:],
    cacheMode: .storage(s3Storage, [.consumer, .producer]),
    overwrite: true,
    verbose: verbose
)

// Create Scipio Runner in Prepare mode
let runner = Runner(
    mode: .prepareDependencies,
    options: options
)

// Run for your package description
try await runner.run(
    packageDirectory: packagePath,
    frameworkOutputDir: .default
)
```

### Authorization Mode

`S3Storage` have two authorization modes.

`.authorized` requires AWS credential to upload/download build artifacts. 
It's good for both cache producer and consumer.

Using `.usePublicURL` mode, S3 client attempt to fetch build artifacts from Public URL.
It doesn't need any authentication. It's good for cache consumers.
In this mode, client can't upload artifacts. So it must not become producers.

If you want to use non-authenticated mode, you have to upload artifacts from producers with `shoudPublishObject` option.
This option indicates ACL to be `publicRead`. It means all artifacts will become public.

```swift
let producerConfig = S3StorageConfig(
    authenticationMode: .authorized(
        accessKeyID: "AWS_ACCESS_KEY_ID", 
        secretAccessKey: "AWS_SECRET_ACCESS_KEY"
    ),
    bucket: "my-bucket",
    region: "ap-northeast-1",
    endpoint: URL(string: "https://my-s3-bucket.com")!,
    shouldPublishObject: true
)

let consumerConfig = S3StorageConfig(
    authenticationMode: .usePublicURL,
    bucket: "my-bucket",
    region: "ap-northeast-1",
    endpoint: URL(string: "https://my-s3-bucket.com")!
)
```

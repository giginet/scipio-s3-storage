# ScipioS3Storage

[Scipio](https://github.com/giginet/Scipio) cache storage backend for AWS S3.

## Swift macro artifacts

`S3Storage` can cache compiler plugin directories through Scipio's `ArtifactCacheStorage` interface. Macro artifacts use `<prefix>/Macros/<target>/<checksum>.aar`; existing XCFramework keys remain `<prefix>/<target>/<checksum>.aar`. The archive contains the executable and its support files, including executable permissions.

Invalid artifacts are marked as unavailable by the storage instance without deleting the remote object. A producer can replace the object with a rebuilt artifact; other consumers may continue to encounter the invalid object until it is replaced. Public URL consumers remain read-only.

This prototype depends on a fixed revision of [Scipio's macro support PR](https://github.com/giginet/Scipio/pull/288). Replace the revision with a released Scipio version before publishing a versioned release of this package.

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

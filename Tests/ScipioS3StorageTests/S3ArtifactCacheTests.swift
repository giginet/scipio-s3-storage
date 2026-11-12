import CacheStorage
import Foundation
import ScipioKit
@testable import ScipioS3Storage
import Testing

struct S3ArtifactCacheTests {
    private struct TestCacheKey: CacheKey {
        let targetName: String
        let revision: String
        var artifactKind: ArtifactKind?
    }

    @Test func `macro and framework round trips use separate keys`() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let artifact = root.appending(path: "plugin")
        let framework = root.appending(path: "ExamplePlugin.xcframework")
        let payload = try makeArtifact(at: artifact)
        try manager.createDirectory(at: framework, withIntermediateDirectories: true)
        try Data("framework".utf8).write(to: framework.appending(path: "binary"))

        let client = MemoryObjectStorage()
        let storage = S3Storage(storageClient: client, storagePrefix: "prefix")
        let frameworkKey = TestCacheKey(targetName: "ExamplePlugin", revision: "one")
        let key = TestCacheKey(targetName: "ExamplePlugin", revision: "one", artifactKind: .macroPlugin)
        let frameworkChecksum = try frameworkKey.calculateChecksum()
        let checksum = try key.calculateChecksum()
        #expect(checksum != frameworkChecksum)
        let missing = try await storage.existsArtifact(for: key, kind: .macroPlugin)
        #expect(!missing)

        try await storage.cacheFramework(framework, for: frameworkKey)
        try await storage.cacheArtifact(artifact, for: key, kind: .macroPlugin)

        let keys = await client.keys()
        #expect(keys == [
            "prefix/ExamplePlugin/\(frameworkChecksum).aar", "prefix/ExamplePlugin/\(checksum).aar"
        ])
        let exists = try await storage.existsArtifact(for: key, kind: .macroPlugin)
        #expect(exists)

        let restoredArtifact = root.appending(path: "restored-plugin")
        let restoredFrameworkRoot = root.appending(path: "restored-framework")
        try await storage.fetchArtifact(for: key, kind: .macroPlugin, to: restoredArtifact)
        try await storage.fetchArtifacts(for: frameworkKey, to: restoredFrameworkRoot)

        let restoredExecutable = restoredArtifact.appending(path: "ExamplePlugin")
        #expect(try Data(contentsOf: restoredExecutable) == payload)
        #expect(manager.isExecutableFile(atPath: restoredExecutable.path))
        #expect(try Data(contentsOf: restoredArtifact.appending(path: "artifact.json")) == Data("manifest".utf8))
        #expect(
            try Data(contentsOf: restoredArtifact.appending(components: "Resources", "data")) == Data("resource".utf8)
        )
        #expect(
            try manager.destinationOfSymbolicLink(atPath: restoredArtifact.appending(path: "resource-link").path)
                == "Resources/data"
        )
        #expect(
            try Data(contentsOf: restoredFrameworkRoot.appending(components: "ExamplePlugin.xcframework", "binary"))
                == Data("framework".utf8)
        )
    }

    private func makeArtifact(at artifact: URL) throws -> Data {
        let manager = FileManager.default
        let resources = artifact.appending(path: "Resources")
        try manager.createDirectory(at: resources, withIntermediateDirectories: true)
        let executable = artifact.appending(path: "ExamplePlugin")
        let payload = Data("macro executable".utf8)
        try payload.write(to: executable)
        try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        try Data("manifest".utf8).write(to: artifact.appending(path: "artifact.json"))
        try Data("resource".utf8).write(to: resources.appending(path: "data"))
        try manager.createSymbolicLink(
            atPath: artifact.appending(path: "resource-link").path,
            withDestinationPath: "Resources/data"
        )
        return payload
    }

    @Test func `invalid artifact is replaced only by a producer`() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("valid".utf8).write(to: root.appending(path: "plugin"))

        let client = MemoryObjectStorage()
        let storage = S3Storage(storageClient: client)
        let otherConsumer = S3Storage(storageClient: client)
        let key = TestCacheKey(targetName: "ExamplePlugin", revision: "one")
        let objectKey = try "ExamplePlugin/\(key.calculateChecksum()).aar"
        try await client.putObject(Data("corrupt".utf8), at: objectKey)

        try await storage.removeArtifact(for: key, kind: .macroPlugin)
        let markedInvalid = try await storage.existsArtifact(for: key, kind: .macroPlugin)
        let stillInStorage = try await otherConsumer.existsArtifact(for: key, kind: .macroPlugin)
        #expect(!markedInvalid)
        #expect(stillInStorage)

        try await storage.cacheArtifact(root, for: key, kind: .macroPlugin)
        let repaired = try await storage.existsArtifact(for: key, kind: .macroPlugin)
        #expect(repaired)
        let destination = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: destination) }
        try await otherConsumer.fetchArtifact(for: key, kind: .macroPlugin, to: destination)
        #expect(try Data(contentsOf: destination.appending(path: "plugin")) == Data("valid".utf8))
    }

    @Test func `unreadable archive is marked invalid`() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let client = MemoryObjectStorage()
        let storage = S3Storage(storageClient: client)
        let key = TestCacheKey(targetName: "ExamplePlugin", revision: "one")
        let objectKey = try "ExamplePlugin/\(key.calculateChecksum()).aar"
        try await client.putObject(Data("corrupt archive".utf8), at: objectKey)

        await #expect(throws: (any Error).self) {
            try await storage.fetchArtifact(for: key, kind: .macroPlugin, to: root)
        }
        let available = try await storage.existsArtifact(for: key, kind: .macroPlugin)
        #expect(!available)
        let keys = await client.keys()
        #expect(keys == [objectKey])
    }

    @Test func `scipio restores framework and macro from storage`() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let package = try makeMacroPackage(at: root)
        let output = root.appending(path: "XCFrameworks")
        let client = MemoryObjectStorage()
        let storage = S3Storage(storageClient: client, storagePrefix: "cache")
        let runner = Runner(mode: .prepareDependencies, options: .init(
            baseBuildOptions: .init(buildConfiguration: .debug, platforms: .specific([.iOS]), frameworkType: .static),
            frameworkCachePolicies: [.init(storage: storage, actors: [.consumer, .producer])],
            resolvedPackagesCachePolicies: [],
            requireMacroArtifactStorage: true
        ))

        try await runner.run(packageDirectory: package, frameworkOutputDir: .custom(output))
        let framework = output.appending(path: "FixtureLibrary.xcframework")
        let macroDirectory = package.appending(components: ".build", "scipio", "MacroPlugins", "FixturePlugin")
        let executable = macroDirectory.appending(path: "FixturePlugin")
        let macroVersion = package.appending(components: ".build", "scipio", "MacroPlugins", ".FixturePlugin.version")
        let original = try Data(contentsOf: executable)
        let objectKeys = await client.keys()
        #expect(objectKeys.contains { $0.hasPrefix("cache/FixtureLibrary/") })
        #expect(objectKeys.contains { $0.hasPrefix("cache/FixturePlugin/") })

        try manager.removeItem(at: macroDirectory)
        try manager.removeItem(at: macroVersion)
        try await runner.run(packageDirectory: package, frameworkOutputDir: .custom(output))
        let firstFetches = await client.fetched()
        #expect(firstFetches.contains { $0.hasPrefix("cache/FixturePlugin/") })
        #expect(!firstFetches.contains { $0.hasPrefix("cache/FixtureLibrary/") })
        #expect(try Data(contentsOf: executable) == original)

        try manager.removeItem(at: framework)
        try manager.removeItem(at: macroDirectory)
        try manager.removeItem(at: macroVersion)
        try await runner.run(packageDirectory: package, frameworkOutputDir: .custom(output))
        let allFetches = await client.fetched()
        #expect(allFetches.contains { $0.hasPrefix("cache/FixtureLibrary/") })
        #expect(manager.fileExists(atPath: framework.path))
        #expect(manager.isExecutableFile(atPath: executable.path))
        #expect(try Data(contentsOf: executable) == original)
        #expect(manager.fileExists(atPath: macroVersion.path))
    }

    private func makeMacroPackage(at root: URL) throws -> URL {
        let manager = FileManager.default
        let source = root.appending(path: "MacroFixture")
        let parent = root.appending(path: "Parent")
        try manager.createDirectory(
            at: source.appending(components: "Sources", "FixturePlugin"),
            withIntermediateDirectories: true
        )
        try manager.createDirectory(
            at: source.appending(components: "Sources", "FixtureLibrary"),
            withIntermediateDirectories: true
        )
        try manager.createDirectory(
            at: parent.appending(components: "Sources", "Parent"),
            withIntermediateDirectories: true
        )
        try """
        // swift-tools-version: 6.0
        import PackageDescription
        import CompilerPluginSupport
        let package = Package(name: "MacroFixture", platforms: [.iOS(.v15)],
            products: [.library(name: "FixtureLibrary", targets: ["FixtureLibrary"])],
            targets: [.macro(name: "FixturePlugin", dependencies: []),
                      .target(name: "FixtureLibrary", dependencies: ["FixturePlugin"])])
        """.write(to: source.appending(path: "Package.swift"), atomically: true, encoding: .utf8)
        try "@main struct Plugin { static func main() {} }".write(
            to: source.appending(components: "Sources", "FixturePlugin", "Plugin.swift"), atomically: true,
            encoding: .utf8
        )
        try "public struct Fixture {}".write(
            to: source.appending(components: "Sources", "FixtureLibrary", "Library.swift"), atomically: true,
            encoding: .utf8
        )
        try initializeFixtureRepository(at: source)
        try """
        // swift-tools-version: 6.0
        import PackageDescription
        let package = Package(name: "Parent", platforms: [.iOS(.v15)],
            dependencies: [.package(url: "\(source.absoluteString)", exact: "1.0.0")],
            targets: [.target(name: "Parent", dependencies: [
                .product(name: "FixtureLibrary", package: "MacroFixture")
            ])])
        """.write(to: parent.appending(path: "Package.swift"), atomically: true, encoding: .utf8)
        try "struct Parent {}".write(
            to: parent.appending(components: "Sources", "Parent", "Parent.swift"), atomically: true, encoding: .utf8
        )
        return parent
    }

    private func initializeFixtureRepository(at source: URL) throws {
        let commands = [
            ["init", "-q"], ["config", "user.email", "test@example.invalid"], ["config", "user.name", "Test"],
            ["add", "."], ["commit", "-qm", "Fixture"], ["tag", "1.0.0"]
        ]
        for arguments in commands {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/git")
            process.arguments = ["-C", source.path] + arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
        }
    }
}

private actor MemoryObjectStorage: ObjectStorageClient {
    enum Error: Swift.Error {
        case missingObject
    }

    private var objects: [String: Data] = [:]
    private var fetchedKeys: [String] = []

    func putObject(_ data: Data, at key: String) async throws {
        objects[key] = data
    }

    func isExistObject(at key: String) async throws -> Bool {
        objects[key] != nil
    }

    func fetchObject(at key: String) async throws -> Data {
        guard let data = objects[key] else { throw Error.missingObject }
        fetchedKeys.append(key)
        return data
    }

    func keys() -> Set<String> {
        Set(objects.keys)
    }

    func fetched() -> [String] {
        fetchedKeys
    }
}

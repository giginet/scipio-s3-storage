import Foundation
@testable import ScipioS3Storage
import Testing

final class CompressorTests {
    private let fileManager = FileManager.default
    private let workspacePath: URL

    init() throws {
        workspacePath = fileManager.temporaryDirectory.appending(path: UUID().uuidString)
        try fileManager.createDirectory(at: workspacePath, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: workspacePath)
    }

    @Test func `round trip preserves file contents`() throws {
        let xcframeworkPath = workspacePath.appending(path: "source.xcframework")
        try fileManager.createDirectory(at: xcframeworkPath, withIntermediateDirectories: true)

        let fileName = "hello.txt"
        let fileBody = UUID().uuidString
        try Data(fileBody.utf8).write(to: xcframeworkPath.appending(path: fileName))

        let archiver = Compressor()
        let compressed = try archiver.compress(xcframeworkPath)
        #expect(!compressed.isEmpty)

        let extractedPath = workspacePath.appending(path: "restored.xcframework")
        try archiver.extract(compressed, to: extractedPath)

        let fileContents = try #require(fileManager.contents(atPath: extractedPath.appending(path: fileName).path))
        #expect(String(bytes: fileContents, encoding: .utf8) == fileBody)
    }
}

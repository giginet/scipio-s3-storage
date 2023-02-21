import Foundation
import ClientRuntime
import System
import Compression
import AppleArchive

struct Compressor {
    private let fileManager: FileManager = .default

    func compress(_ directoryPath: URL) throws -> ByteStream {
        let encodingStream = try createEncodingStream()

        guard let keySet else { throw Error.initializationError }

        let xcframeworkPath = FilePath(directoryPath.path)
        print(xcframeworkPath)
        try encodingStream.writeDirectoryContents(
            archiveFrom: xcframeworkPath,
            keySet: keySet
        )

        guard let data = fileManager.contents(atPath: archivePath.path) else {
            throw Error.compressionError
        }

        return ByteStream.from(data: data)
    }

    enum Error: LocalizedError {
        case initializationError
        case compressionError
    }

    private func createEncodingStream() throws -> ArchiveStream {
        let archiveFilePath = FilePath(archivePath.path)

        guard let writeFileStream = ArchiveByteStream.fileStream(
                path: archiveFilePath,
                mode: .writeOnly,
                options: [ .create ],
                permissions: FilePermissions(rawValue: 0o644)) else {
            throw Error.initializationError
        }
        defer { try? writeFileStream.close() }

        guard let compressStream = ArchiveByteStream.compressionStream(
                using: .lzfse,
                writingTo: writeFileStream) else {
            throw Error.initializationError
        }
        defer { try? compressStream.close() }

        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream) else {
            throw Error.initializationError
        }
        defer { try? encodeStream.close() }
        return encodeStream
    }

    private var archivePath: URL {
        URL(fileURLWithPath: "/Users/jp30698/work/test").appendingPathComponent("xcframework.aar")
    }

    private var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }

    private var keySet: ArchiveHeader.FieldKeySet? {
        ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")
    }
}

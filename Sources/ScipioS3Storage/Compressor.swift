import Foundation
import ClientRuntime
import System
import Compression
import AppleArchive

struct Compressor {
    private let fileManager: FileManager = .default

    func compress(_ directoryPath: URL) throws -> ByteStream {
        guard let keySet else { throw Error.initializationError }

        let source = FilePath(directoryPath.path)

        try ArchiveByteStream.withFileStream(
            path: FilePath(archivePath.path),
            mode: .writeOnly,
            options: [.create, .truncate],
            permissions: [.ownerReadWrite, .groupRead, .otherRead]
        ) { file in
            try ArchiveByteStream.withCompressionStream(using: .lzfse, writingTo: file) { compressor in
                try ArchiveStream.withEncodeStream(writingTo: compressor) { encoder in
                    try encoder.writeDirectoryContents(archiveFrom: source, keySet: keySet)
                }
            }
        }

        guard let data = fileManager.contents(atPath: archivePath.path) else {
            throw Error.compressionError
        }
        defer { try? fileManager.removeItem(at: archivePath) }

        return ByteStream.from(data: data)
    }

    enum Error: LocalizedError {
        case initializationError
        case compressionError
    }

    private var archivePath: URL {
        temporaryDirectory.appendingPathComponent("xcframework.aar")
    }

    private var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }

    private var keySet: ArchiveHeader.FieldKeySet? {
        ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")
    }
}

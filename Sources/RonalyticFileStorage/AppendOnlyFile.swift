//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Adds bytes to the end of a file and forces them onto the disk.
enum AppendOnlyFile {
    static func append(_ data: Data, to url: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !manager.fileExists(atPath: url.path) {
            guard manager.createFile(atPath: url.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()   // fsync: survive a sudden power loss
    }
}

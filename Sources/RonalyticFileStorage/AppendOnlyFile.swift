//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Adds lines to the end of a file and forces them onto the disk.
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

        // forUpdating = read and write. forWritingTo cannot read the last byte.
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }

        var payload = data
        let end = try handle.seekToEnd()
        if end > 0 {
            /// A crash can leave a half-written last line without a newline.
            /// Start on a fresh line, so the new data does not glue onto the damage.
            try handle.seek(toOffset: end - 1)
            let last = try handle.read(upToCount: 1)
            if last?.first != JSONLines.newline {
                payload.insert(JSONLines.newline, at: 0)
            }
            try handle.seekToEnd()

        }

        try handle.write(contentsOf: payload)
        try handle.synchronize()   // fsync: survive a sudden power loss
    }
}

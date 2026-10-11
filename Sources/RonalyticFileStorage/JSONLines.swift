//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Shared helpers for files with one JSON value per line.
enum JSONLines {
    static let newline = UInt8(ascii: "\n")

    /// File contents, or nil when the file does not exist (also if it vanishes while reading).
    static func readData(at url: URL) throws -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }

    /// Decodes every line it can. Lines that fail (for example a line cut off by a crash)
    /// are skipped and counted.
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) -> (values: [T], skipped: Int) {
        let decoder = JSONDecoder()
        var values: [T] = []
        var skipped = 0
        for line in data.split(separator: newline, omittingEmptySubsequences: true) {
            if let value = try? decoder.decode(type, from: Data(line)) {
                values.append(value)
            } else {
                skipped += 1
            }
        }

        return (values, skipped)
    }

    /// Deletes a file. A missing file is fina
    static func removeFile(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }
}

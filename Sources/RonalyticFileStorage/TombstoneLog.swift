//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// A file listing IDs of events that were removed. One JSON string per line.
/// Appended to during normal use, rewritten only by compaction.
struct TombstoneLog: Sendable {
    let url: URL

    func append(_ ids: Set<String>) throws {
        guard !ids.isEmpty else { return }

        try AppendOnlyFile.append(try encode(ids), to: url)
    }

    /// Every removed ID. A missing file means nothing was removed.
    /// Corrupt lines are skipped.
    func readAll() throws -> Set<String> {
        guard let data = try JSONLines.readData(at: url) else { return [] }

        return Set(JSONLines.decode(String.self, from: data).values)
    }

    /// Replaces the whole file in one atomic step. No IDs means the file is deleted.
    func replace(with ids: Set<String>) throws {
        if ids.isEmpty {
            try JSONLines.removeFile(at: url)
        } else {
            try encode(ids).write(to: url, options: .atomic)
        }
    }

    private func encode(_ ids: Set<String>) throws -> Data {
        let encoder = JSONEncoder()
        var data = Data()
        for id in ids.sorted() {
            data.append(try encoder.encode(id))
            data.append(JSONLines.newline)
        }

        return data
    }
}

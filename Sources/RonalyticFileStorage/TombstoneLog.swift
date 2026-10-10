//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// A file listing IDs of events that were removed. One JSON string per line.
/// Like segments, it is only ever appended to.
struct TombstoneLog: Sendable {
    enum LogError: Error, Equatable {
        /// Line numbers start at 1.
        case corruptLine(Int)
    }

    let url: URL

    private static let newline = UInt8(ascii: "\n")

    func append(_ ids: Set<String>) throws {
        guard !ids.isEmpty else { return }

        let encoder = JSONEncoder()
        var data = Data()
        for id in ids.sorted() {
            data.append(try encoder.encode(id))
            data.append(Self.newline)
        }
        try AppendOnlyFile.append(data, to: url)
    }

    /// Every removed ID. A missing file means nothing was removed.
    func readAll() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        var ids = Set<String>()
        let lines = data.split(separator: Self.newline, omittingEmptySubsequences: true)
        for (index, line) in lines.enumerated() {
            do {
                ids.insert(try decoder.decode(String.self, from: Data(line)))
            } catch {
                throw LogError.corruptLine(index + 1)
            }
        }
        return ids
    }
}

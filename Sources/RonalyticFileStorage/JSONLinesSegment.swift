//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// One file of events, one JSON object per line. Only ever appended to.
/// Assumes a single writer: each process owns its own segment file.
struct JSONLinesSegment: Sendable {
    enum SegmentError: Error, Equatable {
        case cannotCreateFile
        /// Line numbers start at 1.
        case corruptLine(Int)
    }

    let url: URL

    private static let newline = UInt8(ascii: "\n")

    /// Adds events after the existing ones and forces them onto the disk.
    func append(_ events: [Event]) throws {
        guard !events.isEmpty else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = Data()
        for event in events {
            data.append(try encoder.encode(event))
            data.append(Self.newline)
        }

        let manager = FileManager.default
        try manager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !manager.fileExists(atPath: url.path) {
            guard manager.createFile(atPath: url.path, contents: nil) else {
                throw SegmentError.cannotCreateFile
            }
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()   // fsync: survive a sudden power loss
    }

    /// Every event in the file, oldest first. A missing file means no events.
    func readAll() throws -> [Event] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        var events: [Event] = []
        let lines = data.split(separator: Self.newline, omittingEmptySubsequences: true)
        for (index, line) in lines.enumerated() {
            do {
                events.append(try decoder.decode(Event.self, from: Data(line)))
            } catch {
                throw SegmentError.corruptLine(index + 1)
            }
        }
        return events
    }
}

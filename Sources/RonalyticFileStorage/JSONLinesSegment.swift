//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// One file of events, one JSON object per line.
/// Appended to during normal use, rewritten only by compaction.
/// Assumes a single writer: each process owns its own segment file.
struct JSONLinesSegment: Sendable {
    struct ReadResult: Equatable {
        let events: [Event]
        /// Lines that could not be decoded, for example one cut off by a crash.
        let skippedLines: Int
    }

    let url: URL

    /// Adds events after the existing ones and forces them onto the disk.
    func append(_ events: [Event]) throws {
        guard !events.isEmpty else { return }

        try AppendOnlyFile.append(try encode(events), to: url)
    }

    /// Every readable event, oldest first. Corrupt lines are skipped, not fatal.
    /// A missing file means no events.
    func read() throws -> ReadResult {
        guard let data = try JSONLines.readData(at: url) else {
            return ReadResult(events: [], skippedLines: 0)
        }

        let decoded = JSONLines.decode(Event.self, from: data)
        return ReadResult(events: decoded.values, skippedLines: decoded.skipped)
    }

    func readAll() throws -> [Event] {
        try read().events
    }

    /// Replaces the whole file in one atomic step. No events means the file is deleted.
    func replace(with events: [Event]) throws {
        if events.isEmpty {
            try JSONLines.removeFile(at: url)
        } else {
            try encode(events).write(to: url, options: .atomic)
        }
    }

    private func encode(_ events: [Event]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = Data()
        for event in events {
            data.append(try encoder.encode(event))
            data.append(JSONLines.newline)
        }

        return data
    }
}

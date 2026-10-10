//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// A QueueStorage that keeps events on disk as JSON Lines files.
///
/// Every instance writes only to its own files (`segment-<writerID>.jsonl`
/// and `tombstones-<writerID>.jsonl`), so an app and its extensions can share
/// one directory without locks. Reading merges every writer's files.
public actor FileQueueStorage: QueueStorage {
    private let directory: URL
    private let segment: JSONLinesSegment
    private let tombstones: TombstoneLog

    /// - Parameters:
    ///   - directory: Folder for the queue files. For extensions, use an App Group container.
    ///   - writerID: Names this instance's files. Use a different one per process.
    public init(directory: URL, writerID: String = UUID().uuidString) {
        self.directory = directory
        self.segment = JSONLinesSegment(
            url: directory.appendingPathComponent("segment-\(writerID).jsonl")
        )
        self.tombstones = TombstoneLog(
            url: directory.appendingPathComponent("tombstones-\(writerID).jsonl")
        )
    }

    public func append(_ events: [Event]) async throws {
        try segment.append(events)
    }

    public func peek(limit: Int) async throws -> [Event] {
        Array(try liveEvents().prefix(max(limit, 0)))
    }

    public func remove(ids: Set<String>) async throws {
        try tombstones.append(ids)
    }

    public func count() async throws -> Int {
        try liveEvents().count
    }

    /// Every stored event that was not removed, oldest first.
    private func liveEvents() throws -> [Event] {
        var removed = Set<String>()
        for url in try files(withPrefix: "tombstones-") {
            removed.formUnion(try TombstoneLog(url: url).readAll())
        }

        let lists = try files(withPrefix: "segment-").map { url in
            try JSONLinesSegment(url: url).readAll().filter { !removed.contains($0.id) }
        }
        return SegmentMerger.merge(lists)
    }

    /// Files of one kind, sorted by name so ties are always resolved the same way.
    private func files(withPrefix prefix: String) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

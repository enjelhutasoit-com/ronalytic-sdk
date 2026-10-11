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
/// Compaction only ever touches the instance's own files.
public actor FileQueueStorage: QueueStorage {
    private let directory: URL
    private let segment: JSONLinesSegment
    private let tombstones: TombstoneLog
    private let compactionThreshold: Int
    private var removedSinceCompaction = 0

    /// - Parameters:
    ///   - directory: Folder for the queue files. For extensions, use an App Group container.
    ///   - writerID: Names this instance's files. Use a different one per process.
    ///   - compactionThreshold: Clean up after this many events were removed.
    public init(
        directory: URL,
        writerID: String = UUID().uuidString,
        compactionThreshold: Int = 100
    ) {
        self.directory = directory
        self.segment = JSONLinesSegment(
            url: directory.appendingPathComponent("segment-\(writerID).jsonl")
        )
        self.tombstones = TombstoneLog(
            url: directory.appendingPathComponent("tombstones-\(writerID).jsonl")
        )
        self.compactionThreshold = max(compactionThreshold, 1)
    }

    public func append(_ events: [Event]) async throws {
        try segment.append(events)
    }

    public func peek(limit: Int) async throws -> [Event] {
        Array(try liveEvents().prefix(max(limit, 0)))
    }

    public func remove(ids: Set<String>) async throws {
        try tombstones.append(ids)

        removedSinceCompaction += ids.count
        if removedSinceCompaction >= compactionThreshold {
            removedSinceCompaction = 0
            // Cleaning up must never fail a remove that already succeeded.
            try? compact()
        }
    }

    public func count() async throws -> Int {
        try liveEvents().count
    }

    /// Drops dead data from this instance's own files.
    func compact() throws {
        let removed = try allTombstonedIDs()

        // 1. Own segment: drop removed events and corrupt lines.
        let own = try segment.read()
        let live = own.events.filter { !removed.contains($0.id) }
        if live.count < own.events.count || own.skippedLines > 0 {
            try segment.replace(with: live)
        }

        // 2. Own tombstones: keep only IDs whose event still exists in some segment.
        let ownTombstones = try tombstones.readAll()
        guard !ownTombstones.isEmpty else { return }

        var existing = Set<String>()
        for url in try files(withPrefix: "segment-") {
            existing.formUnion(try JSONLinesSegment(url: url).readAll().map(\.id))
        }
        let stillNeeded = ownTombstones.intersection(existing)
        if stillNeeded.count < ownTombstones.count {
            try tombstones.replace(with: stillNeeded)
        }
    }

    /// Every stored event that was not removed, oldest first.
    private func liveEvents() throws -> [Event] {
        let removed = try allTombstonedIDs()

        let lists = try files(withPrefix: "segment-").map { url in
            try JSONLinesSegment(url: url).readAll().filter { !removed.contains($0.id) }
        }
        return SegmentMerger.merge(lists)
    }

    private func allTombstonedIDs() throws -> Set<String> {
        var removed = Set<String>()
        for url in try files(withPrefix: "tombstones-") {
            removed.formUnion(try TombstoneLog(url: url).readAll())
        }
        return removed
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

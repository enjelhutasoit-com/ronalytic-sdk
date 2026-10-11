//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport
@testable import RonalyticFileStorage

final class FileQueueStorageTests: XCTestCase {

    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ronalytic-tests-\(UUID().uuidString)", isDirectory: true)

    private var shared: URL { root.appendingPathComponent("shared", isDirectory: true) }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func event(_ id: String, at seconds: TimeInterval) -> Event {
        Event(
            id: id,
            name: "test",
            type: .track,
            timestamp: Date(timeIntervalSince1970: seconds),
            sessionID: "sess-1",
            userID: nil,
            properties: [:]
        )
    }

    private func segmentFileCount() throws -> Int {
        try FileManager.default.contentsOfDirectory(atPath: shared.path)
            .filter { $0.hasPrefix("segment-") }
            .count
    }

    // MARK: - Shared contract (the same rules QueueStorageFake follows)

    func test_satisfiesStorageContract() async throws {
        let make: () -> any QueueStorage = {
            FileQueueStorage(directory: self.root.appendingPathComponent(UUID().uuidString))
        }

        try await QueueStorageContract.emptyStorageHasNothing(make)
        try await QueueStorageContract.peekReturnsAppendOrder(make)
        try await QueueStorageContract.peekRespectsLimit(make)
        try await QueueStorageContract.peekDoesNotRemove(make)
        try await QueueStorageContract.removeDeletesOnlyGivenIDs(make)
        try await QueueStorageContract.removeUnknownIDsIsNoOp(make)
    }

    // MARK: - File specific

    func test_newInstance_seesEventsOfAnEarlierInstance() async throws {
        let first = FileQueueStorage(directory: shared, writerID: "one")
        try await first.append([.fixture(id: "a"), .fixture(id: "b")])

        let reopened = FileQueueStorage(directory: shared, writerID: "two")
        let events = try await reopened.peek(limit: 10)

        XCTAssertEqual(events.map(\.id), ["a", "b"])
    }

    func test_eachWriterGetsItsOwnSegmentFile() async throws {
        let first = FileQueueStorage(directory: shared, writerID: "app")
        let second = FileQueueStorage(directory: shared, writerID: "widget")

        try await first.append([.fixture(id: "a")])
        try await second.append([.fixture(id: "b")])

        XCTAssertEqual(try segmentFileCount(), 2)
    }

    func test_eventsFromTwoWriters_areMergedByTimestamp() async throws {
        let app = FileQueueStorage(directory: shared, writerID: "app")
        let widget = FileQueueStorage(directory: shared, writerID: "widget")

        try await app.append([event("late", at: 2_000)])
        try await widget.append([event("early", at: 1_000)])
        let events = try await app.peek(limit: 10)

        XCTAssertEqual(events.map(\.id), ["early", "late"])
    }

    func test_removeByOneWriter_isSeenByAnother() async throws {
        let app = FileQueueStorage(directory: shared, writerID: "app")
        let widget = FileQueueStorage(directory: shared, writerID: "widget")
        try await app.append([.fixture(id: "a"), .fixture(id: "b")])

        try await widget.remove(ids: ["a"])
        let events = try await app.peek(limit: 10)

        XCTAssertEqual(events.map(\.id), ["b"])
    }

    func test_removedEvents_stayRemovedAfterReopening() async throws {
        let first = FileQueueStorage(directory: shared, writerID: "one")
        try await first.append([.fixture(id: "a"), .fixture(id: "b")])
        try await first.remove(ids: ["a"])

        let reopened = FileQueueStorage(directory: shared, writerID: "two")
        let count = try await reopened.count()

        XCTAssertEqual(count, 1)
    }

    // MARK: - Corruption recovery

    func test_corruptSegmentLine_doesNotBreakPeek() async throws {
        let storage = FileQueueStorage(directory: shared, writerID: "one")
        try await storage.append([.fixture(id: "a")])
        let handle = try FileHandle(forWritingTo: segmentURL("one"))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{garbage".utf8))
        try handle.close()

        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.map(\.id), ["a"])
    }

    // MARK: - Compaction

    func test_compact_deletesFilesWhenEverythingWasRemoved() async throws {
        let storage = FileQueueStorage(directory: shared, writerID: "one")
        try await storage.append([.fixture(id: "a"), .fixture(id: "b")])
        try await storage.remove(ids: ["a", "b"])

        try await storage.compact()

        XCTAssertEqual(try fileNames(), [])
    }

    func test_compact_rewritesSegmentKeepingLiveEvents() async throws {
        let storage = FileQueueStorage(directory: shared, writerID: "one")
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])
        try await storage.remove(ids: ["a"])

        try await storage.compact()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.map(\.id), ["b", "c"])
        XCTAssertEqual(try JSONLinesSegment(url: segmentURL("one")).readAll().count, 2)
    }

    func test_compact_keepsTombstoneWhileTheEventStillExistsInAnotherWriter() async throws {
        let app = FileQueueStorage(directory: shared, writerID: "app")
        let widget = FileQueueStorage(directory: shared, writerID: "widget")
        try await app.append([.fixture(id: "a"), .fixture(id: "b")])
        try await widget.remove(ids: ["a"])

        try await widget.compact()
        let events = try await app.peek(limit: 10)
        let names = try fileNames()

        XCTAssertEqual(events.map(\.id), ["b"])
        XCTAssertTrue(names.contains("tombstones-widget.jsonl"))
    }

    func test_compact_dropsTombstoneOnceTheOwnerCleanedItsSegment() async throws {
        let app = FileQueueStorage(directory: shared, writerID: "app")
        let widget = FileQueueStorage(directory: shared, writerID: "widget")
        try await app.append([.fixture(id: "a"), .fixture(id: "b")])
        try await widget.remove(ids: ["a"])

        try await app.compact()
        try await widget.compact()
        let events = try await app.peek(limit: 10)
        let names = try fileNames()

        XCTAssertEqual(events.map(\.id), ["b"])
        XCTAssertFalse(names.contains("tombstones-widget.jsonl"))
    }

    func test_removingEnoughEvents_triggersCompactionAutomatically() async throws {
        let storage = FileQueueStorage(directory: shared, writerID: "one", compactionThreshold: 2)
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])

        try await storage.remove(ids: ["a"])
        let beforeThreshold = try JSONLinesSegment(url: segmentURL("one")).readAll().count
        try await storage.remove(ids: ["b"])
        let afterThreshold = try JSONLinesSegment(url: segmentURL("one")).readAll().count

        XCTAssertEqual(beforeThreshold, 3)
        XCTAssertEqual(afterThreshold, 1)
    }

    // MARK: - Helper

    private func fileNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: shared.path).sorted()
    }

    private func segmentURL(_ writerID: String) -> URL {
        shared.appendingPathComponent("segment-\(writerID).jsonl")
    }
}

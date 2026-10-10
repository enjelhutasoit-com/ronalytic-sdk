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

    // MARK: - Shared contract (the same rules InMemoryQueueStorage follows)

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
}

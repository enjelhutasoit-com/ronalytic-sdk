//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore
import RonalyticTestSupport

final class BoundedQueueStorageTests: XCTestCase {
    func test_underCapacity_keepsEverything() async throws {
        let queue = makeQueue(capacity: 3, policy: .dropOldest)

        try await queue.append([.fixture(id: "a"), .fixture(id: "b")])
        let ids = try await storedIDs(queue)
        let dropped = await queue.droppedCount

        XCTAssertEqual(ids, ["a", "b"])
        XCTAssertEqual(dropped, 0)
    }

    func test_dropNewest_rejectsIncomingWhenFull() async throws {
        let queue = makeQueue(capacity: 2, policy: .dropNewest)
        try await queue.append([.fixture(id: "a"), .fixture(id: "b")])
        try await queue.append([.fixture(id: "c")])
        let ids = try await storedIDs(queue)
        let dropped = await queue.droppedCount

        XCTAssertEqual(ids, ["a", "b"])
        XCTAssertEqual(dropped, 1)
    }

    func test_dropNewest_acceptsOnlyWhatFits() async throws {
        let queue = makeQueue(capacity: 3, policy: .dropNewest)
        try await queue.append([.fixture(id: "a"), .fixture(id: "b")])
        try await queue.append([.fixture(id: "c"), .fixture(id: "d"), .fixture(id: "e")])
        let ids = try await storedIDs(queue)
        let dropped = await queue.droppedCount

        XCTAssertEqual(ids, ["a", "b", "c"])
        XCTAssertEqual(dropped, 2)
    }

    func test_dropOldest_evictsOldestWhenFull() async throws {
        let queue = makeQueue(capacity: 2, policy: .dropOldest)
        try await queue.append([.fixture(id: "a"), .fixture(id: "b")])
        try await queue.append([.fixture(id: "c")])
        let ids = try await storedIDs(queue)
        let dropped = await queue.droppedCount

        XCTAssertEqual(ids, ["b", "c"])
        XCTAssertEqual(dropped, 1)
    }

    func test_dropOldest_batchLargerThanCapacity_keepsNewest() async throws {
        let queue = makeQueue(capacity: 2, policy: .dropOldest)
        try await queue.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c"), .fixture(id: "d")])
        let ids = try await storedIDs(queue)
        let dropped = await queue.droppedCount

        XCTAssertEqual(ids, ["c", "d"])
        XCTAssertEqual(dropped, 2)
    }

    func test_droppedCount_accumulatesAcrossCalls() async throws {
        let queue = makeQueue(capacity: 1, policy: .dropNewest)
        try await queue.append([.fixture(id: "a")])
        try await queue.append([.fixture(id: "b")])
        try await queue.append([.fixture(id: "c")])
        let dropped = await queue.droppedCount

        XCTAssertEqual(dropped, 2)
    }

    func test_satisfiesStorageContract() async throws {
        let make: () -> any QueueStorage = {
            BoundedQueueStorage(base: InMemoryQueueStorage(), capacity: 100, policy: .dropOldest)
        }
        try await QueueStorageContract.emptyStorageHasNothing(make)
        try await QueueStorageContract.peekReturnsAppendOrder(make)
        try await QueueStorageContract.peekRespectsLimit(make)
        try await QueueStorageContract.peekDoesNotRemove(make)
        try await QueueStorageContract.removeDeletesOnlyGivenIDs(make)
        try await QueueStorageContract.removeUnknownIDsIsNoOp(make)
    }

    // MARK: - Helper

    private func makeQueue(capacity: Int, policy: DropPolicy) -> BoundedQueueStorage {
        BoundedQueueStorage(
            base: InMemoryQueueStorage(),
            capacity: capacity,
            policy: policy
        )
    }

    private func storedIDs(_ queue: BoundedQueueStorage) async throws -> [String] {
        try await queue.peek(limit: 100).map(\.id)
    }
}

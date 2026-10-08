//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class InMemoryQueueStorageTests: XCTestCase {

    private let make: () -> any QueueStorage = { InMemoryQueueStorage() }

    func test_emptyStorage() async throws {
        try await QueueStorageContract.emptyStorageHasNothing(make)
    }

    func test_peekReturnsEventsInAppendOrder() async throws {
        try await QueueStorageContract.peekReturnsAppendOrder(make)
    }

    func test_peekRespectsLimit() async throws {
        try await QueueStorageContract.peekRespectsLimit(make)
    }

    func test_peekDoesNotRemove() async throws {
        try await QueueStorageContract.peekDoesNotRemove(make)
    }

    func test_removeDeletesOnlyGivenIDsAndKeepsOrder() async throws {
        try await QueueStorageContract.removeDeletesOnlyGivenIDs(make)
    }

    func test_removeUnknownIDsIsNoOp() async throws {
        try await QueueStorageContract.removeUnknownIDsIsNoOp(make)
    }
}

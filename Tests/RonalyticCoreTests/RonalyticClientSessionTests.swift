//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientSessionTests: XCTestCase {

    private let storage = InMemoryQueueStorage()
    private let clock = FakeClock()

    func test_eventsWithinTimeout_shareSessionID() async throws {
        let client = makeClient()

        client.track("a")
        clock.advance(by: 60)
        client.screen("Home")
        await client.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(Set(events.map(\.sessionID)).count, 1)
    }

    func test_eventAfterTimeout_getsNewSessionID() async throws {
        let client = makeClient()

        client.track("before")
        clock.advance(by: 1_801)
        client.track("after")
        await client.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.count, 2)
        XCTAssertNotEqual(events[0].sessionID, events[1].sessionID)
    }

    // MARK: - Helper

    private func makeClient() -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: clock,
            idGenerator: SequentialIDGenerator(),
            sessionTimeout: 1_800
        )
    }
}

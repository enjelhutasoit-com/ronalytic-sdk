//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct DropAllPlugin: Plugin {
    let name = "drop-all"
    func process(_ event: Event) async -> Event? { nil }
}

private struct FailingStorage: QueueStorage {
    struct Failure: Error {}
    func append(_ events: [Event]) async throws { throw Failure() }
    func peek(limit: Int) async throws -> [Event] { [] }
    func remove(ids: Set<String>) async throws {}
    func count() async throws -> Int { 0 }
}

final class RonalyticClientMetricsTests: XCTestCase {
    func test_storedEvents_areCounted() async {
        let client = makeClient()

        client.track("a")
        client.track("b")
        await client.waitUntilIdle()
        let snapshot = client.metrics.snapshot()

        XCTAssertEqual(snapshot.eventsStored, 2)
    }

    func test_eventsDroppedByAPlugin_areCounted() async {
        let client = makeClient(plugins: [DropAllPlugin()])

        client.track("a")
        await client.waitUntilIdle()
        let snapshot = client.metrics.snapshot()

        XCTAssertEqual(snapshot.eventsDroppedByPlugin, 1)
        XCTAssertEqual(snapshot.eventsStored, 0)
    }

    func test_eventsDroppedByOptOut_areCounted() async {
        let client = makeClient()

        client.optOut()
        client.track("a")
        client.screen("Home")
        await client.waitUntilIdle()
        let snapshot = client.metrics.snapshot()

        XCTAssertEqual(snapshot.eventsDroppedByOptOut, 2)
        XCTAssertEqual(snapshot.eventsStored, 0)
    }

    func test_storageFailure_isCounted() async {
        let client = makeClient(storage: FailingStorage())

        client.track("a")
        await client.waitUntilIdle()
        let snapshot = client.metrics.snapshot()

        XCTAssertEqual(snapshot.storageFailures, 1)
        XCTAssertEqual(snapshot.eventsStored, 0)
    }

    // MARK: - Helper

    private func makeClient(
        storage: any QueueStorage = InMemoryQueueStorage(),
        plugins: [any Plugin] = []
    ) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            plugins: plugins,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator(),
            optOutStore: InMemoryOptOutStore()
        )
    }
}

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

private struct FailingStorageStub: QueueStorage {
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
        let client = makeClient(storage: FailingStorageStub())

        client.track("a")
        await client.waitUntilIdle()
        let snapshot = client.metrics.snapshot()

        XCTAssertEqual(snapshot.storageFailures, 1)
        XCTAssertEqual(snapshot.eventsStored, 0)
    }

    func test_diagnostics_returnsTheCurrentCounters() async {
        let client = makeClient()

        client.track("a")
        await client.waitUntilIdle()
        let diagnostics = client.diagnostics()

        XCTAssertEqual(diagnostics.eventsStored, 1)
    }

    func test_diagnostics_isACopyThatDoesNotChangeLater() async {
        let client = makeClient()
        client.track("a")
        await client.waitUntilIdle()

        let before = client.diagnostics()
        client.track("b")
        await client.waitUntilIdle()
        let after = client.diagnostics()

        XCTAssertEqual(before.eventsStored, 1)
        XCTAssertEqual(after.eventsStored, 2)
    }

    func test_dropNewest_countsOnlySuccessfullyStoredEvents() async throws {
        let storage = QueueStorageFake()
        let client = makeClient(storage: storage, queueCapacity: 2, dropPolicy: .dropNewest)

        client.track("a")
        client.track("b")
        client.track("c")
        await client.waitUntilIdle()
        let snapshot = client.diagnostics()
        let names = try await storage.peek(limit: 10).map(\.name)

        XCTAssertEqual(snapshot.eventsStored, 2)
        XCTAssertEqual(snapshot.eventsDroppedByQueue, 1)
        XCTAssertEqual(names, ["a", "b"])
    }

    func test_dropOldest_countsSuccessfulWritesAndLaterEvictionsSeparately() async throws {
        let storage = QueueStorageFake()
        let client = makeClient(storage: storage, queueCapacity: 2, dropPolicy: .dropOldest)

        client.track("a")
        client.track("b")
        client.track("c")
        await client.waitUntilIdle()
        let snapshot = client.diagnostics()
        let names = try await storage.peek(limit: 10).map(\.name)

        XCTAssertEqual(snapshot.eventsStored, 3)
        XCTAssertEqual(snapshot.eventsDroppedByQueue, 1)
        XCTAssertEqual(names, ["b", "c"])
    }

    func test_preexistingEvents_areNotCountedAsNewWrites() async throws {
        let storage = QueueStorageFake()
        try await storage.append([.fixture(id: "existing")])
        let client = makeClient(storage: storage, queueCapacity: 2, dropPolicy: .dropNewest)

        client.track("a")
        client.track("b")
        await client.waitUntilIdle()
        let snapshot = client.diagnostics()
        let count = try await storage.count()

        XCTAssertEqual(snapshot.eventsStored, 1)
        XCTAssertEqual(snapshot.eventsDroppedByQueue, 1)
        XCTAssertEqual(count, 2)
    }

    // MARK: - Helper

    private func makeClient(
        storage: any QueueStorage = QueueStorageFake(),
        plugins: [any Plugin] = [],
        queueCapacity: Int = 1_000,
        dropPolicy: DropPolicy = .dropOldest
    ) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            plugins: plugins,
            clock: ClockFake(),
            idGenerator: IDGeneratorFake(),
            queueCapacity: queueCapacity,
            dropPolicy: dropPolicy,
            optOutStore: InMemoryOptOutStore()
        )
    }
}

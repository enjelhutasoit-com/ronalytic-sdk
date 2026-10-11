//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientLifecycleTests: XCTestCase {

    private let storage = InMemoryQueueStorage()
    private let clock = FakeClock()
    private let observer = FakeLifecycleObserver()

    private func makeClient(transport: FakeTransport? = nil) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: clock,
            idGenerator: SequentialIDGenerator(),
            transport: transport,
            sessionTimeout: 1_800,
            lifecycleObserver: observer
        )
    }

    /// Sends one lifecycle event and waits until the client has fully handled it.
    private func deliver(_ event: LifecycleEvent, to client: RonalyticClient) async {
        observer.send(event)
        observer.finish()
        await client.waitUntilLifecycleHandled()
        await client.waitUntilIdle()
    }

    func test_enteringBackground_flushesStoredEvents() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport)
        client.track("a")

        await deliver(.didEnterBackground, to: client)

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.name) }, [["a"]])
    }

    func test_willTerminate_flushesStoredEvents() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport)
        client.track("a")

        await deliver(.willTerminate, to: client)

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.count, 1)
    }

    func test_enteringForeground_doesNotFlush() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport)
        client.track("a")

        await deliver(.willEnterForeground, to: client)

        let batches = await transport.sentBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func test_foregroundWithinTimeout_countsAsActivity() async throws {
        let client = makeClient()
        client.track("a")
        clock.advance(by: 20 * 60)

        await deliver(.willEnterForeground, to: client)
        clock.advance(by: 20 * 60)
        client.track("b")
        await client.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events[0].sessionID, events[1].sessionID)
    }

    func test_foregroundAfterTimeout_startsNewSession() async throws {
        let client = makeClient()
        client.track("a")
        clock.advance(by: 31 * 60)

        await deliver(.willEnterForeground, to: client)
        client.track("b")
        await client.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.map(\.sessionID), ["id-1", "id-3"])
    }
}

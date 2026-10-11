//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private actor BatchCountRecorder {
    private(set) var counts: [Int] = []
    func record(_ count: Int) { counts.append(count) }
}

final class RonalyticClientLifecycleTests: XCTestCase {

    private let storage = InMemoryQueueStorage()
    private let clock = FakeClock()
    private let observer = FakeLifecycleObserver()

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

    func test_backgroundFlush_finishesInsideTheBackgroundTask() async {
        let transport = FakeTransport()
        let seen = BatchCountRecorder()
        let runner = FakeBackgroundTaskRunner(afterWork: {
            await seen.record(await transport.sentBatches.count)
        })
        let client = makeClient(transport: transport, runner: runner)
        client.track("a")

        await deliver(.didEnterBackground, to: client)

        let counts = await seen.counts
        XCTAssertEqual(runner.runCount, 1)
        XCTAssertEqual(counts, [1])
    }

    func test_willTerminate_alsoUsesTheBackgroundTask() async {
        let runner = FakeBackgroundTaskRunner()
        let client = makeClient(transport: FakeTransport(), runner: runner)

        await deliver(.willTerminate, to: client)

        XCTAssertEqual(runner.runCount, 1)
    }

    func test_foreground_doesNotUseTheBackgroundTask() async {
        let runner = FakeBackgroundTaskRunner()
        let client = makeClient(transport: FakeTransport(), runner: runner)

        await deliver(.willEnterForeground, to: client)

        XCTAssertEqual(runner.runCount, 0)
    }

    // MARK: - Helper

    private func makeClient(
        transport: FakeTransport? = nil,
        runner: any BackgroundTaskRunner = ImmediateBackgroundTaskRunner()
    ) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: clock,
            idGenerator: SequentialIDGenerator(),
            transport: transport,
            sessionTimeout: 1_800,
            lifecycleObserver: observer,
            backgroundTaskRunner: runner
        )
    }
}

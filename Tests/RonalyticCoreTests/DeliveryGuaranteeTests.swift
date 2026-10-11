//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

/// Storage whose `remove` fails a set number of times.
/// From the flusher's view this equals an app that died right after
/// the server accepted a batch, but before the events were removed.
private actor RemoveFailsStorage: QueueStorage {
    struct Failure: Error {}

    private let base = InMemoryQueueStorage()
    private var failuresLeft: Int

    init(failures: Int) {
        self.failuresLeft = failures
    }

    func append(_ events: [Event]) async throws {
        try await base.append(events)
    }

    func peek(limit: Int) async throws -> [Event] {
        try await base.peek(limit: limit)
    }

    func remove(ids: Set<String>) async throws {
        if failuresLeft > 0 {
            failuresLeft -= 1
            throw Failure()
        }
        try await base.remove(ids: ids)
    }

    func count() async throws -> Int {
        try await base.count()
    }
}

final class DeliveryGuaranteeTests: XCTestCase {

    private let clock = FakeClock()

    private func ids(_ batches: [[Event]]) -> [[String]] {
        batches.map { $0.map(\.id) }
    }

    // MARK: - At-least-once

    func test_crashAfterServerAccepted_eventIsResentWithTheSameID() async throws {
        let storage = RemoveFailsStorage(failures: 1)
        let transport = FakeTransport()
        try await storage.append([.fixture(id: "a")])

        // The server accepted "a", but the app died before removing it.
        await Flusher(storage: storage, transport: transport, batchSize: 50, backoff: .noRetry).flush()
        let afterCrash = try await storage.count()

        // The app starts again and flushes.
        await Flusher(storage: storage, transport: transport, batchSize: 50, backoff: .noRetry).flush()
        let afterRestart = try await storage.count()
        let batches = await transport.sentBatches

        XCTAssertEqual(afterCrash, 1)
        XCTAssertEqual(afterRestart, 0)
        XCTAssertEqual(ids(batches), [["a"], ["a"]])
    }

    func test_failedRemoval_isRetriedAutomaticallyWithinOneFlush() async throws {
        let storage = RemoveFailsStorage(failures: 1)
        let transport = FakeTransport()
        try await storage.append([.fixture(id: "a")])
        let flusher = Flusher(
            storage: storage,
            transport: transport,
            batchSize: 50,
            backoff: BackoffPolicy(baseDelay: 1, maxDelay: 60, maxRetries: 5),
            clock: clock
        )

        await flusher.flush()
        let remaining = try await storage.count()
        let batches = await transport.sentBatches

        XCTAssertEqual(remaining, 0)
        XCTAssertEqual(ids(batches), [["a"], ["a"]])
    }

    // MARK: - Ordering

    func test_orderIsKeptWhenABatchFailsAndIsRetried() async throws {
        let storage = InMemoryQueueStorage()
        let transport = FakeTransport(responses: [.throwError])
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])
        let flusher = Flusher(
            storage: storage,
            transport: transport,
            batchSize: 2,
            backoff: BackoffPolicy(baseDelay: 1, maxDelay: 60, maxRetries: 5),
            clock: clock
        )

        await flusher.flush()
        let batches = await transport.sentBatches

        XCTAssertEqual(ids(batches), [["a", "b"], ["a", "b"], ["c"]])
    }

    func test_eventThatFailedStaysInFrontOfNewerEvents() async throws {
        let storage = InMemoryQueueStorage()
        let result = DeliveryResult(delivered: ["a", "c"], retryable: ["b"])
        let transport = FakeTransport(responses: [.result(result)])
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])

        await Flusher(storage: storage, transport: transport, batchSize: 50, backoff: .noRetry).flush()
        try await storage.append([.fixture(id: "d")])
        let waiting = try await storage.peek(limit: 10)

        XCTAssertEqual(waiting.map(\.id), ["b", "d"])
    }

    // MARK: - Partial failure, end to end

    func test_partialFailure_fromTrackToStorage() async throws {
        let storage = InMemoryQueueStorage()
        // Session takes id-1, so the three events are id-2, id-3 and id-4.
        let result = DeliveryResult(delivered: ["id-2"], retryable: ["id-3"], rejected: ["id-4"])
        let transport = FakeTransport(responses: [.result(result)])
        let client = RonalyticClient(config: RonalyticConfig(
            storage: storage,
            transport: transport,
            batchSize: 3,
            flushInterval: nil,
            backoff: .noRetry,
            collectContext: false,
            optOutStore: InMemoryOptOutStore(),
            clock: clock,
            idGenerator: SequentialIDGenerator()
        ))

        client.track("delivered")
        client.track("retry later")
        client.track("rejected")
        await client.waitUntilIdle()
        let waiting = try await storage.peek(limit: 10)

        XCTAssertEqual(waiting.map(\.id), ["id-3"])
        XCTAssertEqual(waiting.map(\.name), ["retry later"])
    }
}

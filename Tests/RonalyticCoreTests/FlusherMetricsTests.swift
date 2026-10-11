//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

/// Advances the fake clock while "sending", so a flush has a measurable duration.
private struct SlowTransportStub: Transport {
    let clock: ClockFake
    let seconds: TimeInterval

    func send(_ batch: [Event]) async throws -> DeliveryResult {
        clock.advance(by: seconds)
        return DeliveryResult(delivered: Set(batch.map(\.id)))
    }
}

/// Storage whose `remove` always fails.
private actor RemoveAlwaysFailsStorageStub: QueueStorage {
    struct Failure: Error {}

    private let base = QueueStorageFake()

    func append(_ events: [Event]) async throws { try await base.append(events) }
    func peek(limit: Int) async throws -> [Event] { try await base.peek(limit: limit) }
    func remove(ids: Set<String>) async throws { throw Failure() }
    func count() async throws -> Int { try await base.count() }
}

final class FlusherMetricsTests: XCTestCase {

    private let storage = QueueStorageFake()
    private let clock = ClockFake()
    private let metrics = MetricsRecorder()

    private func makeFlusher(
        storage: (any QueueStorage)? = nil,
        transport: any Transport,
        backoff: BackoffPolicy = .noRetry
    ) -> Flusher {
        Flusher(
            storage: storage ?? self.storage,
            transport: transport,
            batchSize: 50,
            backoff: backoff,
            clock: clock,
            metrics: metrics
        )
    }

    private func store(_ ids: String...) async throws {
        try await storage.append(ids.map { Event.fixture(id: $0) })
    }

    func test_deliveredEvents_areCounted() async throws {
        try await store("a", "b")
        let flusher = makeFlusher(transport: TransportSpy())

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.batchesSent, 1)
        XCTAssertEqual(snapshot.eventsDelivered, 2)
        XCTAssertEqual(snapshot.eventsRejected, 0)
        XCTAssertEqual(snapshot.flushes, 1)
    }

    func test_partialFailure_countsDeliveredAndRejectedOnly() async throws {
        try await store("a", "b", "c")
        let result = DeliveryResult(delivered: ["a"], retryable: ["b"], rejected: ["c"])
        let flusher = makeFlusher(transport: TransportSpy(responses: [.result(result)]))

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.eventsDelivered, 1)
        XCTAssertEqual(snapshot.eventsRejected, 1)
        XCTAssertEqual(snapshot.retries, 0)
    }

    func test_failedSendThenRetry_countsFailureAndRetry() async throws {
        try await store("a")
        let flusher = makeFlusher(
            transport: TransportSpy(responses: [.throwError]),
            backoff: BackoffPolicy(baseDelay: 1, maxDelay: 60, maxRetries: 5)
        )

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.sendFailures, 1)
        XCTAssertEqual(snapshot.retries, 1)
        XCTAssertEqual(snapshot.batchesSent, 1)
        XCTAssertEqual(snapshot.eventsDelivered, 1)
        XCTAssertEqual(snapshot.flushes, 1)
    }

    func test_givingUp_countsEveryFailedSend() async throws {
        try await store("a")
        let flusher = makeFlusher(
            transport: TransportSpy(responses: [.throwError, .throwError]),
            backoff: BackoffPolicy(baseDelay: 1, maxDelay: 60, maxRetries: 1)
        )

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.sendFailures, 2)
        XCTAssertEqual(snapshot.retries, 1)
        XCTAssertEqual(snapshot.eventsDelivered, 0)
    }

    func test_flushDuration_isMeasuredWithTheClock() async throws {
        try await store("a")
        let flusher = makeFlusher(transport: SlowTransportStub(clock: clock, seconds: 2))

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.lastFlushDuration, 2)
        XCTAssertEqual(snapshot.longestFlushDuration, 2)
    }

    func test_flushWithNothingToSend_isNotCounted() async {
        let flusher = makeFlusher(transport: TransportSpy())

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.flushes, 0)
        XCTAssertNil(snapshot.lastFlushDuration)
    }

    func test_failedRemoval_countsStorageFailureAndNoDelivery() async throws {
        let failing = RemoveAlwaysFailsStorageStub()
        try await failing.append([.fixture(id: "a")])
        let flusher = makeFlusher(storage: failing, transport: TransportSpy())

        await flusher.flush()
        let snapshot = metrics.snapshot()

        XCTAssertEqual(snapshot.batchesSent, 1)
        XCTAssertEqual(snapshot.storageFailures, 1)
        XCTAssertEqual(snapshot.eventsDelivered, 0)
    }
}

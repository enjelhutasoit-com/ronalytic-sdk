//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct FixedJitter: JitterSource {
    let value: Double
    func nextUnit() -> Double { value }
}

final class FlusherRetryTests: XCTestCase {
    private let storage = InMemoryQueueStorage()
    private let clock = FakeClock()

    func test_wholeBatchFailure_waitsThenRetriesAndDelivers() async throws {
        try await store("a")
        let transport = FakeTransport(responses: [.throwError])
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()
        let batches = await transport.sentBatches
        let remaining = try await storedIDs()

        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(clock.sleeps, [.seconds(1)])
        XCTAssertEqual(remaining, [])
    }

    func test_waitsGrowExponentially() async throws {
        try await store("a")
        let transport = FakeTransport(responses: [.throwError, .throwError, .throwError])
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()

        XCTAssertEqual(
            clock.sleeps,
            [.seconds(1), .seconds(2), .seconds(4)]
        )
    }

    func test_givesUpAfterMaxRetries_andKeepsEvents() async throws {
        try await store("a")
        let responses = Array(repeating: FakeTransport.Response.throwError, count: 5)
        let transport = FakeTransport(responses: responses)
        let flusher = makeFlusher(
            transport: transport,
            backoff: BackoffPolicy(
                baseDelay: 1,
                maxDelay: 60,
                maxRetries: 2
            )
        )

        await flusher.flush()
        let batches = await transport.sentBatches
        let remaining = try await storedIDs()

        XCTAssertEqual(batches.count, 3) // first try plus two retries
        XCTAssertEqual(clock.sleeps.count, 2)
        XCTAssertEqual(remaining, ["a"])
    }

    func test_waitIsCappedAtMaxDelay() async throws {
        try await store("a")
        let responses = Array(repeating: FakeTransport.Response.throwError, count: 4)
        let transport = FakeTransport(responses: responses)
        let flusher = makeFlusher(
            transport: transport,
            backoff: BackoffPolicy(baseDelay: 1, maxDelay: 3, maxRetries: 4)
        )

        await flusher.flush()

        XCTAssertEqual(
            clock.sleeps,
            [.seconds(1), .seconds(2), .seconds(3), .seconds(3)]
        )
    }

    func test_jitterScalesTheWait() async throws {
        try await store("a")
        let transport = FakeTransport(responses: [.throwError])
        let flusher = makeFlusher(transport: transport, jitter: 0.5)

        await flusher.flush()

        XCTAssertEqual(clock.sleeps, [.seconds(0.5)])
    }

    func test_retryableEvents_areRetriedAfterWaiting() async throws {
        try await store("a", "b")
        let result = DeliveryResult(delivered: ["a"], retryable: ["b"])
        let transport = FakeTransport(responses: [.result(result)])
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()
        let batches = await transport.sentBatches
        let remaining = try await storedIDs()

        XCTAssertEqual(batches.map { $0.map(\.id) }, [["a", "b"], ["b"]])
        XCTAssertEqual(clock.sleeps, [.seconds(1)])
        XCTAssertEqual(remaining, [])
    }

    func test_successResetsTheFailureCount() async throws {
        try await store("a", "b")
        let transport = FakeTransport(responses: [.throwError, .deliverAll, .throwError])
        let flusher = makeFlusher(transport: transport, batchSize: 1)

        await flusher.flush()

        XCTAssertEqual(clock.sleeps, [.seconds(1), .seconds(1)])
    }

    // MARK: - Helper

    private func makeFlusher(
        transport: FakeTransport,
        batchSize: Int = 50,
        backoff: BackoffPolicy = BackoffPolicy(
            baseDelay: 1,
            maxDelay: 60,
            maxRetries: 5
        ),
        jitter: Double = 1.0
    ) -> Flusher {
        Flusher(
            storage: storage,
            transport: transport,
            batchSize: batchSize,
            backoff: backoff,
            clock: clock,
            jitter: FixedJitter(value: jitter)
        )
    }

    private func store(_ ids: String...) async throws {
        try await storage.append(ids.map { Event.fixture(id: $0) })
    }

    private func storedIDs() async throws -> [String] {
        try await storage.peek(limit: 100).map(\.id)
    }
}

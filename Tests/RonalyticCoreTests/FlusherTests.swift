//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class FlusherTests: XCTestCase {

    private let storage = InMemoryQueueStorage()

    private func makeFlusher(transport: FakeTransport, batchSize: Int = 50) -> Flusher {
        Flusher(storage: storage, transport: transport, batchSize: batchSize)
    }

    private func store(_ ids: String...) async throws {
        try await storage.append(ids.map { Event.fixture(id: $0) })
    }

    private func storedIDs() async throws -> [String] {
        try await storage.peek(limit: 100).map(\.id)
    }

    func test_emptyQueue_sendsNothing() async {
        let transport = FakeTransport()
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()

        let batches = await transport.sentBatches
        XCTAssertTrue(batches.isEmpty)
    }

    func test_deliveredEvents_areRemoved() async throws {
        try await store("a", "b")
        let transport = FakeTransport()
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()

        let remaining = try await storedIDs()
        XCTAssertEqual(remaining, [])
    }

    func test_sendsInBatchesOfTheConfiguredSize() async throws {
        try await store("a", "b", "c", "d", "e")
        let transport = FakeTransport()
        let flusher = makeFlusher(transport: transport, batchSize: 2)

        await flusher.flush()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.id) }, [["a", "b"], ["c", "d"], ["e"]])
    }

    func test_wholeBatchFailure_keepsEventsAndStops() async throws {
        try await store("a", "b", "c")
        let transport = FakeTransport(responses: [.throwError])
        let flusher = makeFlusher(transport: transport, batchSize: 2)

        await flusher.flush()

        let remaining = try await storedIDs()
        let batches = await transport.sentBatches
        XCTAssertEqual(remaining, ["a", "b", "c"])
        XCTAssertEqual(batches.count, 1)
    }

    func test_partialFailure_removesDeliveredAndRejected_keepsRetryable() async throws {
        try await store("a", "b", "c")
        let result = DeliveryResult(delivered: ["a"], retryable: ["b"], rejected: ["c"])
        let transport = FakeTransport(responses: [.result(result)])
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()

        let remaining = try await storedIDs()
        XCTAssertEqual(remaining, ["b"])
    }

    func test_retryableEvents_stopTheFlush() async throws {
        try await store("a", "b", "c")
        let result = DeliveryResult(delivered: ["a"], retryable: ["b"])
        let transport = FakeTransport(responses: [.result(result)])
        let flusher = makeFlusher(transport: transport, batchSize: 2)

        await flusher.flush()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.count, 1)
    }

    func test_eventsMissingFromTheResult_areKept() async throws {
        try await store("a", "b")
        let transport = FakeTransport(responses: [.result(DeliveryResult(delivered: ["a"]))])
        let flusher = makeFlusher(transport: transport)

        await flusher.flush()

        let remaining = try await storedIDs()
        XCTAssertEqual(remaining, ["b"])
    }
}

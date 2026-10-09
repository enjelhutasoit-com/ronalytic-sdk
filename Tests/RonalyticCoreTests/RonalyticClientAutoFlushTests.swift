//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientAutoFlushTests: XCTestCase {
    private let storage = InMemoryQueueStorage()

    func test_reachingBatchSize_flushesWithoutExplicitFlush() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport, batchSize: 3)

        ["a", "b", "c"].forEach { client.track($0) }
        await client.waitUntilIdle()

        let batches = await transport.sentBatches

        XCTAssertEqual(
            batches.map { $0.map(\.name) },
            [["a", "b", "c"]]
        )
    }

    func test_belowBatchSize_doesNotFlush() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport, batchSize: 3)

        ["a", "b"].forEach { client.track($0) }
        await client.waitUntilIdle()
        let batches = await transport.sentBatches

        XCTAssertTrue(batches.isEmpty)
    }

    func test_autoFlush_removesDeliveredEvents() async throws {
        let transport = FakeTransport()
        let client = makeClient(transport: transport, batchSize: 2)

        ["a", "b"].forEach { client.track($0) }
        await client.waitUntilIdle()
        let count = try await storage.count()

        XCTAssertEqual(count, 0)
    }

    func test_flushesEachTimeTheThresholdIsReached() async throws {
        let transport = FakeTransport()
        let client = makeClient(transport: transport, batchSize: 2)

        ["a", "b", "c", "d", "e"].forEach { client.track($0) }
        await client.waitUntilIdle()
        let batches = await transport.sentBatches
        let remaining = try await storage.count()

        XCTAssertEqual(
            batches.map { $0.map(\.name) },
            [["a", "b"], ["c", "d"]]
        )
        XCTAssertEqual(remaining, 1)
    }

    func test_withoutTransport_neverFlushes() async throws {
        let client = makeClient(transport: nil, batchSize: 1)

        client.track("a")
        await client.waitUntilIdle()

        let count = try await storage.count()

        XCTAssertEqual(count, 1)
    }

    // MARK: - Helper

    private func makeClient(transport: FakeTransport?, batchSize: Int) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator(),
            transport: transport,
            batchSize: batchSize
        )
    }
}

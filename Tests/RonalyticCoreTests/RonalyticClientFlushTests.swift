//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientFlushTests: XCTestCase {

    private let storage = InMemoryQueueStorage()

    private func makeClient(transport: FakeTransport?) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator(),
            transport: transport
        )
    }

    func test_flush_sendsEventsTrackedBeforeIt() async {
        let transport = FakeTransport()
        let client = makeClient(transport: transport)

        client.track("a")
        client.track("b")
        client.flush()
        await client.waitUntilIdle()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.name) }, [["a", "b"]])
    }

    func test_flush_removesDeliveredEventsFromStorage() async throws {
        let client = makeClient(transport: FakeTransport())

        client.track("a")
        client.flush()
        await client.waitUntilIdle()

        let count = try await storage.count()
        XCTAssertEqual(count, 0)
    }

    func test_flushWithoutTransport_keepsEvents() async throws {
        let client = makeClient(transport: nil)

        client.track("a")
        client.flush()
        await client.waitUntilIdle()

        let count = try await storage.count()
        XCTAssertEqual(count, 1)
    }
}

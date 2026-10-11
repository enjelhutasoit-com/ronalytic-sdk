//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientFlushTests: XCTestCase {

    private let storage = QueueStorageFake()

    private func makeClient(transport: TransportSpy?) -> RonalyticClient {
        RonalyticClient(
            storage: storage,
            clock: ClockFake(),
            idGenerator: IDGeneratorFake(),
            transport: transport
        )
    }

    func test_flush_sendsEventsTrackedBeforeIt() async {
        let transport = TransportSpy()
        let client = makeClient(transport: transport)

        client.track("a")
        client.track("b")
        client.flush()
        await client.waitUntilIdle()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.name) }, [["a", "b"]])
    }

    func test_flush_removesDeliveredEventsFromStorage() async throws {
        let client = makeClient(transport: TransportSpy())

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

    func test_flush_retriesAfterATemporaryFailure() async throws {
        let transport = TransportSpy(responses: [.throwError])
        let client = makeClient(transport: transport)

        client.track("a")
        client.flush()
        await client.waitUntilIdle()
        let batches = await transport.sentBatches
        let count = try await storage.count()

        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(count, 0)
    }
}

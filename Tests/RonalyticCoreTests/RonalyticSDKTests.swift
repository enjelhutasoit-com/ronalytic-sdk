//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticSDKTests: XCTestCase {

    override func setUp() async throws {
        RonalyticSDK.reset()
    }

    override func tearDown() async throws {
        RonalyticSDK.reset()
    }

    func test_callsBeforeConfigure_doNothingAndDoNotCrash() {
        RonalyticSDK.track("a")
        RonalyticSDK.screen("Home")
        RonalyticSDK.identify("user-1")
        RonalyticSDK.flush()

        XCTAssertNil(RonalyticSDK.client)
    }

    func test_configureThenTrack_reachesStorage() async throws {
        let storage = InMemoryQueueStorage()
        RonalyticSDK.configure(makeConfig(storage: storage))

        RonalyticSDK.track("purchase", properties: ["price": 9.99])
        await RonalyticSDK.client?.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.map(\.name), ["purchase"])
        XCTAssertEqual(events.first?.properties["price"], .double(9.99))
    }

    func test_configureTwice_firstConfigWins() async throws {
        let first = InMemoryQueueStorage()
        let second = InMemoryQueueStorage()
        RonalyticSDK.configure(makeConfig(storage: first))
        RonalyticSDK.configure(makeConfig(storage: second))

        RonalyticSDK.track("a")
        await RonalyticSDK.client?.waitUntilIdle()

        let firstCount = try await first.count()
        let secondCount = try await second.count()
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 0)
    }

    func test_trackScreenAndIdentify_areForwarded() async throws {
        let storage = InMemoryQueueStorage()
        RonalyticSDK.configure(makeConfig(storage: storage))

        RonalyticSDK.track("a")
        RonalyticSDK.screen("Home")
        RonalyticSDK.identify("user-1", traits: ["plan": "pro"])
        await RonalyticSDK.client?.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.map(\.type), [.track, .screen, .identify])
        XCTAssertEqual(events.last?.userID, "user-1")
    }

    func test_flush_sendsStoredEvents() async {
        let transport = FakeTransport()
        RonalyticSDK.configure(makeConfig(storage: InMemoryQueueStorage(), transport: transport))

        RonalyticSDK.track("a")
        RonalyticSDK.flush()
        await RonalyticSDK.client?.waitUntilIdle()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.name) }, [["a"]])
    }

    // MARK: - Helper

    private func makeConfig(
        storage: InMemoryQueueStorage,
        transport: FakeTransport? = nil
    ) -> RonalyticConfig {
        RonalyticConfig(
            storage: storage,
            transport: transport,
            flushInterval: nil,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        )
    }
}

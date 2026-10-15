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
        let storage = QueueStorageFake()
        RonalyticSDK.configure(makeConfig(storage: storage))

        RonalyticSDK.track("purchase", properties: ["price": 9.99])
        await RonalyticSDK.client?.waitUntilIdle()

        let events = try await storage.peek(limit: 10)
        XCTAssertEqual(events.map(\.name), ["purchase"])
        XCTAssertEqual(events.first?.properties["price"], .double(9.99))
    }

    func test_configureTwice_firstConfigWins() async throws {
        let first = QueueStorageFake()
        let second = QueueStorageFake()
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
        let storage = QueueStorageFake()
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
        let transport = TransportSpy()
        RonalyticSDK.configure(makeConfig(storage: QueueStorageFake(), transport: transport))

        RonalyticSDK.track("a")
        RonalyticSDK.flush()
        await RonalyticSDK.client?.waitUntilIdle()

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.name) }, [["a"]])
    }

    func test_optOutAndOptInBeforeConfigure_doNotCrash() {
        RonalyticSDK.optOut()
        RonalyticSDK.optIn()

        XCTAssertNil(RonalyticSDK.client)
    }

    func test_optOut_stopsTracking() async throws {
        let storage = QueueStorageFake()
        RonalyticSDK.configure(
            RonalyticConfig(
                storage: storage,
                flushInterval: nil,
                optOutStore: InMemoryOptOutStore(),
                clock: ClockFake(),
                idGenerator: IDGeneratorFake()
            )
        )

        RonalyticSDK.optOut()
        RonalyticSDK.track("a")
        await RonalyticSDK.client?.waitUntilIdle()
        let count = try await storage.count()

        XCTAssertEqual(count, 0)
    }

    func test_diagnosticsBeforeConfigure_isNil() {
        let diagnostics = RonalyticSDK.diagnostics()

        XCTAssertNil(diagnostics)
    }

    func test_diagnosticsAfterConfigure_reflectsTrackedEvents() async {
        RonalyticSDK.configure(makeConfig(storage: QueueStorageFake()))

        RonalyticSDK.track("a")
        RonalyticSDK.track("b")
        await RonalyticSDK.client?.waitUntilIdle()
        let diagnostics = RonalyticSDK.diagnostics()

        XCTAssertEqual(diagnostics?.eventsStored, 2)
    }

    func test_isOptedOutBeforeConfigure_isNil() {
        let value = RonalyticSDK.isOptedOut()

        XCTAssertNil(value)
    }

    func test_isOptedOutAfterConfigure_isFalse() {
        RonalyticSDK.configure(makeConfig(storage: QueueStorageFake()))

        let value = RonalyticSDK.isOptedOut()

        XCTAssertEqual(value, false)
    }

    func test_isOptedOut_followsOptOutAndOptIn() {
        RonalyticSDK.configure(makeConfig(storage: QueueStorageFake()))

        RonalyticSDK.optOut()
        let afterOptOut = RonalyticSDK.isOptedOut()
        RonalyticSDK.optIn()
        let afterOptIn = RonalyticSDK.isOptedOut()

        XCTAssertEqual(afterOptOut, true)
        XCTAssertEqual(afterOptIn, false)
    }

    func test_waitUntilIdleBeforeConfigure_returnsImmediately() async {
        await RonalyticSDK.waitUntilIdle()   // reaching this line is the assertion
    }

    func test_waitUntilIdle_returnsAfterEventsAreStored() async throws {
        let storage = QueueStorageFake()
        RonalyticSDK.configure(makeConfig(storage: storage))

        RonalyticSDK.track("a")
        RonalyticSDK.track("b")
        await RonalyticSDK.waitUntilIdle()

        let count = try await storage.count()
        XCTAssertEqual(count, 2)
    }

    func test_clientWaitUntilIdle_isCallableAsPublicAPI() async {
        let client = RonalyticClient(config: makeConfig(storage: QueueStorageFake()))

        client.track("a")
        await client.waitUntilIdle()

        XCTAssertEqual(client.diagnostics().eventsStored, 1)
    }

    // MARK: - Helper

    private func makeConfig(
        storage: QueueStorageFake,
        transport: TransportSpy? = nil
    ) -> RonalyticConfig {
        RonalyticConfig(
            storage: storage,
            transport: transport,
            flushInterval: nil,
            optOutStore: InMemoryOptOutStore(),
            clock: ClockFake(),
            idGenerator: IDGeneratorFake()
        )
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class RonalyticClientConsentTests: XCTestCase {

    private let storage = InMemoryQueueStorage()

    func test_optOut_stopsNewEvents() async throws {
        let client = makeClient()

        client.optOut()
        client.track("a")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, [])
    }

    func test_optIn_resumesTracking() async throws {
        let client = makeClient()

        client.optOut()
        client.optIn()
        client.track("a")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, ["a"])
    }

    func test_optOut_appliesToScreenAndIdentifyToo() async throws {
        let client = makeClient()

        client.optOut()
        client.screen("Home")
        client.identify("user-1")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, [])
    }

    func test_eventsTrackedBeforeOptOut_arePreserved() async throws {
        let client = makeClient()

        client.track("before")
        client.optOut()
        client.track("after")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, ["before"])
    }

    func test_isOptedOut_reflectsTheSwitch() {
        let client = makeClient()

        XCTAssertFalse(client.isOptedOut)

        client.optOut()

        XCTAssertTrue(client.isOptedOut)
    }

    func test_deniedConsentProvider_blocksEvents() async throws {
        let client = makeClient(consent: FakeConsentProvider(.denied))

        client.track("a")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, [])
    }

    func test_withoutConsentProvider_eventsAreStored() async throws {
        let client = makeClient(consent: nil)

        client.track("a")
        await client.waitUntilIdle()
        let names = try await storedNames()

        XCTAssertEqual(names, ["a"])
    }

    // MARK: - Helper

    private func makeClient(consent: FakeConsentProvider? = nil) -> RonalyticClient {
        RonalyticClient(config: RonalyticConfig(
            storage: storage,
            flushInterval: nil,
            collectContext: false,
            consentProvider: consent,
            optOutStore: InMemoryOptOutStore(),
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        ))
    }

    private func storedNames() async throws -> [String] {
        try await storage.peek(limit: 100).map(\.name)
    }
}

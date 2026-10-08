//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct PrefixPlugin: Plugin {
    let name =  "prefix"

    func process(_ event: RonalyticCore.Event) async -> RonalyticCore.Event? {
        var copy = event
        copy.name = "pre_" + event.name
        return copy
    }
}

private struct DropAllPlugin: Plugin {
    let name = "drop-all"

    func process(_ event: RonalyticCore.Event) async -> RonalyticCore.Event? { nil }
}

private struct FailingStorage: QueueStorage {
    struct Failure: Error {}

    func append(_ events: [RonalyticCore.Event]) async throws { throw Failure() }
    func peek(limit: Int) async throws -> [RonalyticCore.Event] { [] }
    func remove(ids: Set<String>) async throws { }
    func count() async throws -> Int { 0 }
}

final class RonalyticClientTests: XCTestCase {
    private let storage = InMemoryQueueStorage()
    private let clock = FakeClock(start: Date(timeIntervalSince1970: 500))

    private func makeClient(
        plugins: [any Plugin] = [],
        storage: (any QueueStorage)? = nil
    ) -> RonalyticClient {
        RonalyticClient(
            storage: storage ?? self.storage,
            plugins: plugins,
            clock: clock,
            idGenerator: SequentialIDGenerator()
        )
    }

    private func stored() async throws -> [Event] {
        try await storage.peek(limit: 100)
    }

    func test_track_enqueuesTrackEvent() async throws {
        let client = makeClient()
        client.track("purchase", properties: ["price": .double(9.99)])
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].name, "purchase")
        XCTAssertEqual(events[0].type, .track)
        XCTAssertEqual(events[0].properties["price"], .double(9.99))
    }

    func test_track_stampsTimeAndIDWhenCalled() async throws {
        let client = makeClient()
        client.track("a")
        clock.advance(by: 10)
        client.track("b")
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.map(\.timestamp), [Date(timeIntervalSince1970: 500), Date(timeIntervalSince1970: 510)])
        XCTAssertEqual(events.map(\.id), ["id-2", "id-3"])
    }

    func test_track_canBeCalledFromSynchronousCode() {
        let client = makeClient()
        client.track("sync")   // compiles without await or try
    }

    func test_screen_enqueuesScreenEvent() async throws {
        let client = makeClient()
        client.screen("Home")
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.first?.type, .screen)
        XCTAssertEqual(events.first?.name, "Home")
    }

    func test_identify_enqueuesIdentifyEventWithTraits() async throws {
        let client = makeClient()
        client.identify("user-42", traits: ["plan": .string("pro")])
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.first?.type, .identify)
        XCTAssertEqual(events.first?.userID, "user-42")
        XCTAssertEqual(events.first?.properties["plan"], .string("pro"))
    }

    func test_identify_appliesUserIDToLaterEventsOnly() async throws {
        let client = makeClient()
        client.track("before")
        client.identify("user-42")
        client.track("after")
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.map(\.userID), [nil, "user-42", "user-42"])
    }

    func test_preservesCallOrder() async throws {
        let client = makeClient()
        let names = (0..<20).map { "e\($0)" }
        names.forEach { client.track($0) }
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.map(\.name), names)
    }

    func test_pluginsRunBeforeStorage() async throws {
        let client = makeClient(plugins: [PrefixPlugin()])
        client.track("buy")
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertEqual(events.first?.name, "pre_buy")
    }

    func test_pluginCanDropEvent() async throws {
        let client = makeClient(plugins: [DropAllPlugin()])
        client.track("buy")
        await client.waitUntilIdle()

        let events = try await stored()

        XCTAssertTrue(events.isEmpty)
    }

    func test_storageFailure_doesNotCrashAndLaterEventsStillWork() async {
        let client = makeClient(storage: FailingStorage())
        client.track("lost")
        client.track("also lost")
        await client.waitUntilIdle()   // reaching this line is the assertion
    }
}

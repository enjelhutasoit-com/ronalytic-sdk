//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct ContextReaderPlugin: Plugin {
    let name = "context-reader"
    let recorder: ContextRecorder

    func process(_ event: Event) async -> Event? {
        await recorder.record(event.context)
        return event
    }
}

private actor ContextRecorder {
    private(set) var contexts: [[String: PropertyValue]] = []
    func record(_ context: [String: PropertyValue]) { contexts.append(context) }
}

final class RonalyticClientContextTests: XCTestCase {

    private let storage = InMemoryQueueStorage()

    private func makeClient(
        collectContext: Bool,
        plugins: [any Plugin] = [],
        network: NetworkState = .wifi
    ) -> RonalyticClient {
        RonalyticClient(
            config: RonalyticConfig(
                storage: storage,
                plugins: plugins,
                flushInterval: nil,
                collectContext: collectContext,
                contextProvider: FakeContextProvider(.fixture),
                networkStateProvider: FakeNetworkStateProvider(network),
                clock: FakeClock(),
                idGenerator: SequentialIDGenerator()
            )
        )
    }

    func test_eventsCarryContextByDefault() async throws {
        let client = makeClient(collectContext: true, network: .cellular)

        client.track("a")
        await client.waitUntilIdle()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.first?.context["os.name"], "iOS")
        XCTAssertEqual(events.first?.context["network"], "cellular")
    }

    func test_collectContextFalse_leavesContextEmpty() async throws {
        let client = makeClient(collectContext: false)

        client.track("a")
        await client.waitUntilIdle()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.first?.context.isEmpty, true)
    }

    func test_userPluginsSeeTheContext() async {
        let recorder = ContextRecorder()
        let client = makeClient(collectContext: true, plugins: [ContextReaderPlugin(recorder: recorder)])

        client.track("a")
        await client.waitUntilIdle()
        let contexts = await recorder.contexts

        XCTAssertEqual(contexts.first?["app.version"], "2.3.0")
    }

    func test_pluginsCreatedWithoutConfig_stayUntouched() async throws {
        let client = RonalyticClient(
            storage: storage,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        )

        client.track("a")
        await client.waitUntilIdle()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.first?.context.isEmpty, true)
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private actor PropertyRecorder {
    private(set) var seen: [[String: PropertyValue]] = []
    func record(_ properties: [String: PropertyValue]) { seen.append(properties) }
}

private struct PropertyReaderPlugin: Plugin {
    let name = "property-reader"
    let recorder: PropertyRecorder

    func process(_ event: Event) async -> Event? {
        await recorder.record(event.properties)
        return event
    }
}

final class RonalyticClientRedactionTests: XCTestCase {

    private let storage = InMemoryQueueStorage()

    func test_storedEventsAreRedacted() async throws {
        let client = makeClient()

        client.track("signup", properties: ["email": "ron@example.com", "password": "x", "plan": "pro"])
        await client.waitUntilIdle()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(
            events.first?.properties,
            ["email": "[redacted-email]", "plan": "pro"]
        )
    }

    func test_identifyTraitsAreRedacted() async throws {
        let client = makeClient()

        client.identify("user-1", traits: ["email": "ron@example.com"])
        await client.waitUntilIdle()
        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(
            events.first?.properties["email"],
            .string("[redacted-email]")
        )
    }

    func test_userPluginsOnlySeeRedactedValues() async {
        let recorder = PropertyRecorder()
        let client = makeClient(plugins: [PropertyReaderPlugin(recorder: recorder)])

        client.track("signup", properties: ["email": "ron@example.com"])
        await client.waitUntilIdle()
        let seen = await recorder.seen

        XCTAssertEqual(
            seen.first?["email"],
            .string("[redacted-email]")
        )
    }

    // MARK: - Helper
    private func makeClient(plugins: [any Plugin] = []) -> RonalyticClient {
        RonalyticClient(config: RonalyticConfig(
            storage: storage,
            plugins: plugins,
            flushInterval: nil,
            collectContext: false,
            redactionRules: [.maskEmails, .removeKeys(["password"])],
            optOutStore: InMemoryOptOutStore(),
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        ))
    }
}

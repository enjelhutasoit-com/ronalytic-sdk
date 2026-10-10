//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct DropAllPlugin: Plugin {
    let name = "drop-all"
    func process(_ event: Event) async -> Event? { nil }
}

private struct FailingStorage: QueueStorage {
    struct Failure: Error {}
    func append(_ events: [Event]) async throws { throw Failure() }
    func peek(limit: Int) async throws -> [Event] { [] }
    func remove(ids: Set<String>) async throws {}
    func count() async throws -> Int { 0 }
}

final class RonalyticClientLoggingTests: XCTestCase {

    private let logger = RecordingLogger()

    func test_storedEvent_isLoggedAsVerbose() async {
        let client = makeClient()

        client.track("a")
        await client.waitUntilIdle()

        XCTAssertEqual(logger.entries, [LogEntry(.verbose, #"stored track "a" id=id-2"#)])
    }

    func test_eventDroppedByPlugin_isLoggedAsVerbose() async {
        let client = makeClient(plugins: [DropAllPlugin()])

        client.track("a")
        await client.waitUntilIdle()

        XCTAssertEqual(logger.entries, [LogEntry(.verbose, #"dropped by a plugin: track "a" id=id-2"#)])
    }

    func test_storageFailure_isLoggedAsError() async {
        let client = makeClient(storage: FailingStorage())

        client.track("a")
        await client.waitUntilIdle()

        XCTAssertEqual(logger.entries.first?.level, .error)
        XCTAssertTrue(logger.entries.first?.message.hasPrefix("could not store") == true)
    }

    // MARK: - Helper
    private func makeClient(
        storage: any QueueStorage = InMemoryQueueStorage(),
        plugins: [any Plugin] = []
    ) -> RonalyticClient {
        RonalyticClient(
            config: RonalyticConfig(
                storage: storage,
                plugins: plugins,
                flushInterval: nil,
                collectContext: false,
                optOutStore: InMemoryOptOutStore(),
                logger: logger,
                clock: FakeClock(),
                idGenerator: SequentialIDGenerator()
            )
        )
    }
}

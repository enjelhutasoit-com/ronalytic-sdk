//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import  RonalyticTestSupport
@testable import  RonalyticCore

private struct NamedPlugin: Plugin {
    let name: String

    func process(_ event: RonalyticCore.Event) async -> RonalyticCore.Event? { event }
}

final class RonalyticConfigTests: XCTestCase {
    func test_defaults() {
        let config = RonalyticConfig(storage: InMemoryQueueStorage())

        XCTAssertEqual(config.batchSize, 50)
        XCTAssertEqual(config.flushInterval, .seconds(30))
        XCTAssertEqual(config.backoff, .default)
        XCTAssertEqual(config.queueCapacity, 1_000)
        XCTAssertEqual(config.dropPolicy, .dropOldest)
        XCTAssertTrue(config.plugins.isEmpty)
        XCTAssertNil(config.transport)
    }

    func test_customValuesAreKept() {
        let config = RonalyticConfig(
            storage: InMemoryQueueStorage(),
            plugins: [NamedPlugin(name: "one")],
            batchSize: 10,
            flushInterval: .seconds(5),
            backoff: .noRetry,
            queueCapacity: 200,
            dropPolicy: .dropNewest
        )

        XCTAssertEqual(config.plugins.map(\.name), ["one"])
        XCTAssertEqual(config.batchSize, 10)
        XCTAssertEqual(config.flushInterval, .seconds(5))
        XCTAssertEqual(config.backoff, .noRetry)
        XCTAssertEqual(config.queueCapacity, 200)
        XCTAssertEqual(config.dropPolicy, .dropNewest)
    }

    func test_flushIntervalCanBeDisabled() {
        let config = RonalyticConfig(
            storage: InMemoryQueueStorage(),
            flushInterval: nil
        )

        XCTAssertNil(config.flushInterval)
    }

    func test_sessionTimeoutDefaultsToThirtyMinutes() {
        let config = RonalyticConfig(storage: InMemoryQueueStorage())

        XCTAssertEqual(config.sessionTimeout, 1_800)
    }

    func test_collectContextDefaultsToTrue() {
        let config = RonalyticConfig(storage: InMemoryQueueStorage())

        XCTAssertTrue(config.collectContext)
    }

    func test_consentProviderDefaultsToNil() {
        let config = RonalyticConfig(storage: InMemoryQueueStorage())

        XCTAssertNil(config.consentProvider)
    }

    func test_unknownConsentIsNotAllowedByDefault() {
        let config = RonalyticConfig(storage: InMemoryQueueStorage())

        XCTAssertFalse(config.allowWhenConsentUnknown)
    }
}

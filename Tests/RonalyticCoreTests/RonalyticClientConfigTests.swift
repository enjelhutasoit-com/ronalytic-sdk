//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private struct PrefixPlugin: Plugin {
    let name = "prefix"
    func process(_ event: Event) async -> Event? {
        var copy = event
        copy.name = "pre_" + event.name
        return copy
    }
}

final class RonalyticClientConfigTests: XCTestCase {
    func test_initWithConfig_appliesPluginsTransportAndBatchSize() async {
        let transport = FakeTransport()
        let config = RonalyticConfig(
            storage: InMemoryQueueStorage(),
            transport: transport,
            plugins: [PrefixPlugin()],
            batchSize: 2,
            flushInterval: nil,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        )
        let client = RonalyticClient(config: config)

        client.track("a")
        client.track("b")
        await client.waitUntilIdle()
        let batches = await transport.sentBatches

        XCTAssertEqual(
            batches.map { $0.map(\.name)
            },
            [["pre_a", "pre_b"]]
        )
    }
}

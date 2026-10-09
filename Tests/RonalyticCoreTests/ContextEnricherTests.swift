//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class ContextEnricherTests: XCTestCase {
    func test_addsDeviceAndAppContext() async {
        let enricher = makeEnricher()

        let result = await enricher.process(.fixture())

        XCTAssertEqual(result?.context["os.name"], "iOS")
        XCTAssertEqual(result?.context["os.version"], "17.2.1")
        XCTAssertEqual(result?.context["device.model"], "iPhone15,2")
        XCTAssertEqual(result?.context["locale"], "en_US")
        XCTAssertEqual(result?.context["app.version"], "2.3.0")
        XCTAssertEqual(result?.context["app.build"], "45")
        XCTAssertEqual(result?.context["app.bundleID"], "com.example.app")
    }

    func test_addsNetworkState() async {
        let enricher = makeEnricher(
            network: FakeNetworkStateProvider(.cellular)
        )

        let result = await enricher.process(.fixture())

        XCTAssertEqual(result?.context["network"], "cellular")
    }

    func test_readsNetworkStateForEveryEvent() async {
        let network = FakeNetworkStateProvider(.wifi)
        let enricher = makeEnricher(network: network)

        let first = await enricher.process(.fixture(id: "a"))
        await network.setState(.offline)
        let second = await enricher.process(.fixture(id: "b"))

        XCTAssertEqual(first?.context["network"], "wifi")
        XCTAssertEqual(second?.context["network"], "offline")
    }

    func test_doesNotTouchNameOrProperties() async {
        var event = Event.fixture(name: "purchase")
        event.properties = ["price": 9.99]
        let enricher = makeEnricher()

        let result = await enricher.process(event)

        XCTAssertEqual(result?.name, "purchase")
        XCTAssertEqual(result?.properties, ["price": 9.99])
    }

    func test_keepsOtherContextKeys_butOverwritesItsOwn() async {
        var event = Event.fixture()
        event.context = ["custom": "keep", "app.version": "old"]
        let enricher = makeEnricher()

        let result = await enricher.process(event)

        XCTAssertEqual(result?.context["custom"], "keep")
        XCTAssertEqual(result?.context["app.version"], "2.3.0")
    }

    // MARK: - Helper

    private func makeEnricher(network: FakeNetworkStateProvider = FakeNetworkStateProvider(.wifi)) -> ContextEnricher {
        ContextEnricher(
            contextProvider: FakeContextProvider(.fixture),
            networkStateProvider: network
        )
    }
}

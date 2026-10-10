//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class ConsentGateTests: XCTestCase {
    func test_granted_letsEventThrough() async {
        let gate = ConsentGate(
            provider: FakeConsentProvider(.granted),
            allowWhenUnknown: false
        )

        let result = await gate.process(.fixture())

        XCTAssertNotNil(result)
    }

    func test_denied_dropEvent() async {
        let gate = ConsentGate(
            provider: FakeConsentProvider(.denied),
            allowWhenUnknown: true
        )

        let result = await gate.process(.fixture())

        XCTAssertNil(result)
    }

    func test_unknown_dropsEventByDefault() async {
        let gate = ConsentGate(
            provider: FakeConsentProvider(.unknown),
            allowWhenUnknown: false
        )

        let result = await gate.process(.fixture())

        XCTAssertNil(result)
    }

    func test_unknown_letsEventThroughWhenAllowed() async {
        let gate = ConsentGate(
            provider: FakeConsentProvider(.unknown),
            allowWhenUnknown: true
        )

        let result = await gate.process(.fixture())

        XCTAssertNotNil(result)
    }

    func test_readsStatusForEveryEvent() async {
        let provider = FakeConsentProvider(.granted)
        let gate = ConsentGate(
            provider: provider,
            allowWhenUnknown: false
        )

        let first = await gate.process(.fixture(id: "a"))
        await provider.setStatus(.denied)
        let second = await gate.process(.fixture(id: "b"))

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }
}

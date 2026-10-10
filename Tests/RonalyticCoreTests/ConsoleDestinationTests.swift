//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class ConsoleDestinationTests: XCTestCase {

    private let recorder = LineRecorder()

    func test_printsOneReadableLinePerEvent() async {
        var event = Event.fixture(name: "purchase")
        event.properties = ["plan": "pro", "price": 9.99, "qty": 2, "vip": true]

        _ = await makeDestination().process(event)

        XCTAssertEqual(
            recorder.lines,
            [#"[Ronalytic] track "purchase" user=- session=sess-1 props={plan: "pro", price: 9.99, qty: 2, vip: true}"#]
        )
    }

    func test_showsUserIDWhenKnown() async {
        var event = Event.fixture(name: "a")
        event.userID = "user-42"

        _ = await makeDestination().process(event)

        XCTAssertTrue(recorder.lines.first?.contains("user=user-42") == true)
    }

    func test_sortsPropertiesByKey() async {
        var event = Event.fixture()
        event.properties = ["b": 2, "a": 1]

        _ = await makeDestination().process(event)

        XCTAssertTrue(recorder.lines.first?.hasSuffix("props={a: 1, b: 2}") == true)
    }

    func test_emptyProperties() async {
        _ = await makeDestination().process(.fixture())

        XCTAssertTrue(recorder.lines.first?.hasSuffix("props={}") == true)
    }

    func test_returnsEventUnchanged_soLaterPluginsStillRun() async {
        let event = Event.fixture(name: "a")

        let result = await makeDestination().process(event)

        XCTAssertEqual(result, event)
    }

    // MARK: - Helper
    private func makeDestination() -> ConsoleDestination {
        ConsoleDestination(output: { [recorder] in recorder.add($0) })
    }
}

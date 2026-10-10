//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

private func appending(_ suffix: String) -> RedactionRule {
    RedactionRule { _, value in
        guard case .string(let text) = value else { return value }
        return .string(text + suffix)
    }
}

final class RedactorTests: XCTestCase {
    func test_noRules_returnsEventUnchanged() async {
        var event = Event.fixture()
        event.properties = ["email": "ron@example.com"]
        let redactor = Redactor(rules: [])

        let result = await redactor.process(event)

        XCTAssertEqual(result, event)
    }

    func test_removedProperty_disappears() async {
        var event = Event.fixture()
        event.properties = ["password": "secret", "plan": "pro"]
        let redactor = Redactor(rules: [.removeKeys(["password"])])

        let result = await redactor.process(event)

        XCTAssertEqual(result?.properties, ["plan": "pro"])
    }

    func test_rulesRunInOrder() async {
        var event = Event.fixture()
        event.properties = ["note": "x"]
        let redactor = Redactor(rules: [appending("A"), appending("B")])

        let result = await redactor.process(event)

        XCTAssertEqual(result?.properties["note"], .string("xAB"))
    }

    func test_onlyTouchesProperties() async {
        var event = Event.fixture(name: "ron@example.com")
        event.userID = "ron@example.com"
        event.context = ["note": "ron@example.com"]
        let redactor = Redactor(rules: [.maskEmails])

        let result = await redactor.process(event)

        XCTAssertEqual(result?.name, "ron@example.com")
        XCTAssertEqual(result?.userID, "ron@example.com")
        XCTAssertEqual(result?.context["note"], .string("ron@example.com"))
    }
}

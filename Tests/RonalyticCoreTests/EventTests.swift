//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class EventTests: XCTestCase {
    func test_roundTripsThroughJSON() throws {
        let event = makeEvent()
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: data)

        XCTAssertEqual(decoded, event)
    }

    func test_carriesCurrentSchemaVersion() {
        XCTAssertEqual(makeEvent().schemaVersion, Event.currentSchemaVersion)
    }

    func test_propertyValue_encodesAsPlainJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let props: [String: PropertyValue] = [
            "a": .int(1),
            "c": .string("x"),
            "b": .bool(true)
        ]
        let json = String(decoding: try encoder.encode(props), as: UTF8.self)

        XCTAssertEqual(json, #"{"a":1,"b":true,"c":"x"}"#)
    }

    func test_propertyValue_rejectsUnsupportedJSON() {
        let data = Data(#"{"a":[1,2]}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode([String: PropertyValue].self, from: data))
    }

    // MARK: - Helpers

    private func makeEvent() -> Event {
        Event(
            id: "evt-1",
            name: "purchase",
            type: .track,
            timestamp: Date(timeIntervalSince1970: 1_000),
            sessionID: "sess-1",
            userID: nil,
            properties: [
                "price": .double(9.99),
                "qty": .int(3),
                "vip": .bool(true),
                "plan": .string("pro")
            ]
        )
    }
}

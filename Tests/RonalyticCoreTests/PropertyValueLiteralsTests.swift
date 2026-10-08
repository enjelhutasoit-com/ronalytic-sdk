//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class PropertyValueLiteralsTests: XCTestCase {
    func test_stringLiteral_becomesString() {
        let value: PropertyValue = "pro"

        XCTAssertEqual(value, .string("pro"))
    }

    func test_integerLiteral_becomesInt() {
        let value: PropertyValue = 3

        XCTAssertEqual(value, .int(3))
    }

    func test_floatLiteral_becomesDouble() {
        let value: PropertyValue = 9.99

        XCTAssertEqual(value, .double(9.99))
    }

    func test_wholeNumberFloatLiteral_staysDouble() {
        let value: PropertyValue = 2.0

        XCTAssertEqual(value, .double(2.0))
    }

    func test_booleanLiteral_becomesBool() {
        let value: PropertyValue = true

        XCTAssertEqual(value, .bool(true))
    }

    func test_dictionaryLiteral_acceptsMixedValues() {
        let properties: [String: PropertyValue] = [
            "plan": "pro",
            "qty": 3,
            "price": 9.99,
            "vip": false
        ]

        XCTAssertEqual(properties["plan"], .string("pro"))
        XCTAssertEqual(properties["qty"], .int(3))
        XCTAssertEqual(properties["price"], .double(9.99))
        XCTAssertEqual(properties["vip"], .bool(false))
    }

    func test_track_acceptsLiteralProperties() async throws {
        let storage = InMemoryQueueStorage()
        let client = RonalyticClient(
            storage: storage,
            clock: FakeClock(),
            idGenerator: SequentialIDGenerator()
        )

        client.track(
            "purchase",
            properties: [
                "price": 9.99,
                "qty": 2
            ]
        )
        await client.waitUntilIdle()

        let events = try await storage.peek(limit: 10)

        XCTAssertEqual(events.first?.properties["price"], .double(9.99))
        XCTAssertEqual(events.first?.properties["qty"], .int(2))
    }
}

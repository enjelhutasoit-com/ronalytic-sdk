//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticTestSupport
@testable import RonalyticCore

final class SessionTrackerTests: XCTestCase {
    func test_firstCall_startsSession() {
        let tracker = makeTracker()

        let id = tracker.sessionID(at: date(minute: 0))

        XCTAssertEqual(id, "id-1")
    }

    func test_callsWithinTimeout_shareSession() {
        let tracker = makeTracker()

        let first = tracker.sessionID(at: date(minute: 0))
        let second = tracker.sessionID(at: date(minute: 10))

        XCTAssertEqual(first, second)
    }

    func test_exactlyAtTimeout_stillSameSession() {
        let tracker = makeTracker()

        let first = tracker.sessionID(at: date(minute: 0))
        let second = tracker.sessionID(at: date(minute: 30))

        XCTAssertEqual(first, second)
    }

    func test_afterTimeout_startsNewSession() {
        let tracker = makeTracker()

        let first = tracker.sessionID(at: date(minute: 0))
        let second = tracker.sessionID(at: date(minute: 31))

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(second, "id-2")
    }

    func test_activityExtendsTheSession() {
        let tracker = makeTracker()

        let first = tracker.sessionID(at: date(minute: 0))
        _ = tracker.sessionID(at: date(minute: 20))
        let third = tracker.sessionID(at: date(minute: 40))

        XCTAssertEqual(first, third)
    }

    func test_clockGoingBackwards_keepsSession() {
        let  tracker = makeTracker()

        let first = tracker.sessionID(at: date(minute: 10))
        let second = tracker.sessionID(at: date(minute: 5))

        XCTAssertEqual(first, second)
    }

    // MARK: - Helper

    private func makeTracker(timeout: TimeInterval = 1_800) -> SessionTracker {
        SessionTracker(
            timeout: timeout,
            idGenerator: SequentialIDGenerator()
        )
    }

    private func date(minute: Double) -> Date {
        Date(timeIntervalSince1970: minute * 60)
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class FakeTests: XCTestCase {

    func test_fakeClock_startsAtGivenDate() {
        let start = Date(timeIntervalSince1970: 500)

        XCTAssertEqual(FakeClock(start: start).now(), start)
    }

    func test_fakeClock_advanceMovesTime() {
        let clock = FakeClock(start: Date(timeIntervalSince1970: 0))
        clock.advance(by: 30)

        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 30))
    }

    func test_fakeClock_sleepReturnsImmediatelyRecordsAndAdvances() async throws {
        let clock = FakeClock(start: Date(timeIntervalSince1970: 0))
        try await clock.sleep(for: .seconds(2))

        XCTAssertEqual(clock.sleeps, [.seconds(2)])
        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 2))
    }

    func test_sequentialIDGenerator_producesOrderedIDs() {
        let generator = SequentialIDGenerator()

        XCTAssertEqual(generator.makeID(), "id-1")
        XCTAssertEqual(generator.makeID(), "id-2")
    }

    func test_fakes_canBeUsedThroughTheProtocols() {
        let clock: any SDKClock = FakeClock()
        let generator: any IDGenerator = SequentialIDGenerator(prefix: "evt")

        XCTAssertEqual(clock.now(), Date(timeIntervalSince1970: 0))
        XCTAssertEqual(generator.makeID(), "evt-1")
    }
}

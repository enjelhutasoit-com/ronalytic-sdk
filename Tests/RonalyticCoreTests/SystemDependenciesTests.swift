//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class SystemDependenciesTests: XCTestCase {

    func test_systemClock_nowIsCloseToCurrentDate() {
        let difference = abs(SystemClock().now().timeIntervalSinceNow)
        XCTAssertLessThan(difference, 1)
    }

    func test_systemClock_sleepCompletes() async throws {
        try await SystemClock().sleep(for: .milliseconds(10))
    }

    func test_uuidGenerator_producesUniqueNonEmptyIDs() {
        let generator = UUIDGenerator()
        let first = generator.makeID()
        let second = generator.makeID()
        XCTAssertFalse(first.isEmpty)
        XCTAssertNotEqual(first, second)
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class BackoffPolicyTests: XCTestCase {
    private let policy = BackoffPolicy(
        baseDelay: 1,
        maxDelay: 60,
        maxRetries: 5
    )

    func test_delayDoublesEachRetry() {
        let delays = (0..<4).map { policy.delay(forRetry: $0, jitter: 1.0) }

        XCTAssertEqual(delays, [1, 2, 4, 8])
    }

    func test_delayIsCappedAtMax() {
        let delay = policy.delay(forRetry: 20, jitter: 1.0)

        XCTAssertEqual(delay, 60)
    }

    func test_jitterScalesTheDelay() {
        let half = policy.delay(forRetry: 2, jitter: 0.5)
        let none = policy.delay(forRetry: 2, jitter: 0)

        XCTAssertEqual(half, 2)
        XCTAssertEqual(none, 0)
    }

    func test_jitterOutsideZeroToOne_isClamped() {
        let high = policy.delay(forRetry: 1, jitter: 5)
        let low = policy.delay(forRetry: 1, jitter: -3)

        XCTAssertEqual(high, 2)
        XCTAssertEqual(low, 0)
    }
}

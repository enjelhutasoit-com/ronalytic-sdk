//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

/// Allows a fixed number of sleeps, then throws so the timer loop ends.
private final class LimitedClock: SDKClock, @unchecked Sendable {
    struct Exhausted: Error {}

    private let lock = NSLock()
    private let maxSleeps: Int
    private var sleeps: [Duration] = []

    var recordedSleeps: [Duration] {
        lock.withLock { sleeps }
    }

    init(maxSleeps: Int) {
        self.maxSleeps = maxSleeps
    }

    func now() -> Date {
        Date(timeIntervalSince1970: 0)
    }

    func sleep(for duration: Duration) async throws {
        let allowed = lock.withLock { () -> Bool in
            guard sleeps.count < maxSleeps else { return false }
            sleeps.append(duration)
            return true
        }
        if !allowed { throw Exhausted() }
    }
}

private actor TickCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

final class  FlushTimerTests: XCTestCase {
    func test_ticksOncePerInterval() async {
        let clock = LimitedClock(maxSleeps: 3)
        let ticks = TickCounter()

        await FlushTimer.run(every: .seconds(30), clock: clock) { await ticks.increment() }

        let count = await ticks.count

        XCTAssertEqual(count, 3)
        XCTAssertEqual(
            clock.recordedSleeps,
            [.seconds(30), .seconds(30), .seconds(30)]
        )
    }

    func test_stopsWhenSleepFails_withoutTicking() async {
        let clock = LimitedClock(maxSleeps: 0)
        let ticks = TickCounter()

        await FlushTimer.run(every: .seconds(30), clock: clock) { await ticks.increment() }
        let count = await ticks.count

        XCTAssertEqual(count, 0)
    }

    func test_stopsWhenCanceled() async {
        let task = Task {
            await FlushTimer.run(every: .seconds(60), clock: SystemClock()) { }
        }

        task.cancel()
        await task.value

        XCTAssertTrue(task.isCancelled)
    }
}

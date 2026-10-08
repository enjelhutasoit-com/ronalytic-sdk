//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Controllable clock for tests. `sleep` returns immediately,
/// records the duration and moves the fake time forward.
public final class FakeClock: SDKClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private var recordedSleeps: [Duration] = []

    public init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.current = start
    }

    public func now() -> Date {
        lock.withLock { current }
    }

    public func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }

    public var sleeps: [Duration] {
        lock.withLock { recordedSleeps }
    }

    public func sleep(for duration: Duration) async throws {
        let parts = duration.components
        let seconds = Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        lock.withLock {
            recordedSleeps.append(duration)
            current = current.addingTimeInterval(seconds)
        }
    }
}

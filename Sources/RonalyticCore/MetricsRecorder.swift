//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Collects the counters. A lock is used instead of an actor,
/// because `track()` is synchronous and must not `await`.
final class MetricsRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var current = MetricsSnapshot()

    func record(_ update: (inout MetricsSnapshot) -> Void) {
        lock.withLock { update(&current) }
    }

    func snapshot() -> MetricsSnapshot {
        lock.withLock { current }
    }
}

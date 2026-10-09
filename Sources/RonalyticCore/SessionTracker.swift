//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Decides which session an event belongs to.
/// A new session starts when more than `timeout` seconds passed since the last event.
final class SessionTracker: @unchecked Sendable {
    private let lock = NSLock()
    private let timeout: TimeInterval
    private let idGenerator: any IDGenerator
    private var currentID: String?
    private var lastActivity: Date?

    init(
        timeout: TimeInterval,
        idGenerator: any IDGenerator
    ) {
        self.timeout = max(timeout, 0)
        self.idGenerator = idGenerator
    }

    /// Returns the session for an event that happened at `now`
    /// and counts that event as activity.
    func sessionID(at now: Date) -> String {
        lock.withLock { () -> String in
            if let id = currentID,
               let last = lastActivity,
               now.timeIntervalSince(last) <= timeout {
                lastActivity = max(last, now) // a clock going backward must not shrink it
                return id
            }

            let id = idGenerator.makeID()
            currentID = id
            lastActivity = now
            return id
        }
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Counts how often it ran, and can run a check right after the work finished.
public final class FakeBackgroundTaskRunner: BackgroundTaskRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var runs = 0
    private let afterWork: (@Sendable () async -> Void)?

    public init(afterWork: (@Sendable () async -> Void)? = nil) {
        self.afterWork = afterWork
    }

    public var runCount: Int {
        lock.withLock { runs }
    }

    public func run(_ work: @Sendable () async -> Void) async {
        lock.withLock { runs += 1 }
        await work()
        await afterWork?()
    }
}

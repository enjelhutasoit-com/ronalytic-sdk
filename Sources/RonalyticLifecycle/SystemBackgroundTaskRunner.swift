//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Runs work inside a background task: begin, work, end.
/// The task is ended exactly once, also when the system says time is up.
public struct SystemBackgroundTaskRunner: BackgroundTaskRunner {
    static let taskName = "com.ronalytic.flush"

    private let api: any BackgroundTaskAPI

    public init(api: any BackgroundTaskAPI) {
        self.api = api
    }

    public func run(_ work: @Sendable () async -> Void) async {
        let task = ActiveTask(api: api)
        await task.begin(name: Self.taskName)
        await work()
        task.end()
    }
}

/// One background task. `end()` is safe to call many times and from any thread.
private final class ActiveTask: @unchecked Sendable {
    private let api: any BackgroundTaskAPI
    private let lock = NSLock()
    private var identifier: Int?
    private var finished = false

    init(api: any BackgroundTaskAPI) {
        self.api = api
    }

    func begin(name: String) async {
        guard let started = await api.beginTask(name: name, onExpiration: { [self] in self.end() }) else {
            return
        }
        let alreadyOver = lock.withLock { () -> Bool in
            if finished { return true }
            identifier = started
            return false
        }
        if alreadyOver { api.endTask(started) }
    }

    func end() {
        let toEnd = lock.withLock { () -> Int? in
            finished = true
            let current = identifier
            identifier = nil
            return current
        }
        if let toEnd { api.endTask(toEnd) }
    }
}

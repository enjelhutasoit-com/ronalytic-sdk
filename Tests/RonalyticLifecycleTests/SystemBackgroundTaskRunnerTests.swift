//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticLifecycle

private final class BackgroundTaskAPIFake: BackgroundTaskAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []
    private var expirationHandler: (@Sendable () -> Void)?
    private let accepts: Bool

    init(accepts: Bool = true) {
        self.accepts = accepts
    }

    var log: [String] {
        lock.withLock { entries }
    }

    func record(_ entry: String) {
        lock.withLock { entries.append(entry) }
    }

    func beginTask(name: String, onExpiration: @escaping @Sendable () -> Void) async -> Int? {
        lock.withLock {
            entries.append("begin:\(name)")
            expirationHandler = onExpiration
        }
        return accepts ? 7 : nil
    }

    func endTask(_ id: Int) {
        record("end:\(id)")
    }

    /// Simulates iOS saying "time is up".
    func expire() {
        let handler = lock.withLock { expirationHandler }
        handler?()
    }
}

final class SystemBackgroundTaskRunnerTests: XCTestCase {

    func test_beginsBeforeTheWork_andEndsAfterIt() async {
        let api = BackgroundTaskAPIFake()
        let runner = SystemBackgroundTaskRunner(api: api)

        await runner.run { api.record("work") }

        XCTAssertEqual(api.log, ["begin:com.ronalytic.flush", "work", "end:7"])
    }

    func test_expiration_endsTheTaskOnce() async {
        let api = BackgroundTaskAPIFake()
        let runner = SystemBackgroundTaskRunner(api: api)

        await runner.run {
            api.expire()
            api.record("work")
        }

        XCTAssertEqual(api.log, ["begin:com.ronalytic.flush", "end:7", "work"])
    }

    func test_whenTheSystemRefusesATask_theWorkStillRuns() async {
        let api = BackgroundTaskAPIFake(accepts: false)
        let runner = SystemBackgroundTaskRunner(api: api)

        await runner.run { api.record("work") }

        XCTAssertEqual(api.log, ["begin:com.ronalytic.flush", "work"])
    }

    func test_theWorkRunsExactlyOnce() async {
        let api = BackgroundTaskAPIFake()
        let runner = SystemBackgroundTaskRunner(api: api)

        await runner.run { api.record("work") }

        XCTAssertEqual(api.log.filter { $0 == "work" }.count, 1)
    }
}

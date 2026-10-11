//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class MetricsSnapshotTests: XCTestCase {
    func test_summary_ofAFreshSnapshot() {
        let snapshot = MetricsSnapshot()

        let summary = snapshot.summary

        XCTAssertEqual(
            summary,
            "stored=0 dropped(plugin=0 queue=0 optOut=0) storageFailures=0 "
                + "batches=0 sendFailures=0 delivered=0 rejected=0 retries=0 "
                + "flushes=0 lastFlush=- longestFlush=0.0s"
        )
    }

    func test_summary_showsEveryCounter() {
        var snapshot = MetricsSnapshot()
        snapshot.eventsStored = 10
        snapshot.eventsDroppedByPlugin = 1
        snapshot.eventsDroppedByQueue = 2
        snapshot.eventsDroppedByOptOut = 3
        snapshot.storageFailures = 4
        snapshot.batchesSent = 5
        snapshot.sendFailures = 6
        snapshot.eventsDelivered = 7
        snapshot.eventsRejected = 8
        snapshot.retries = 9
        snapshot.flushes = 11
        snapshot.lastFlushDuration = 1.5
        snapshot.longestFlushDuration = 2.5

        let summary = snapshot.summary

        XCTAssertEqual(
            summary,
            "stored=10 dropped(plugin=1 queue=2 optOut=3) storageFailures=4 "
                + "batches=5 sendFailures=6 delivered=7 rejected=8 retries=9 "
                + "flushes=11 lastFlush=1.5s longestFlush=2.5s"
        )
    }

    func test_summary_isASingleLine() {
        let summary = MetricsSnapshot().summary

        XCTAssertFalse(summary.contains("\n"))
    }
}

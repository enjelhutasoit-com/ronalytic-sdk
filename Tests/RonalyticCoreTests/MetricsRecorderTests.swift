//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class MetricsRecorderTests: XCTestCase {

    func test_startsWithAllZeros() {
        let recorder = MetricsRecorder()

        let snapshot = recorder.snapshot()

        XCTAssertEqual(snapshot, MetricsSnapshot())
        XCTAssertNil(snapshot.lastFlushDuration)
    }

    func test_recordUpdatesTheSnapshot() {
        let recorder = MetricsRecorder()

        recorder.record {
            $0.retries += 2
            $0.lastFlushDuration = 1.5
        }
        let snapshot = recorder.snapshot()

        XCTAssertEqual(snapshot.retries, 2)
        XCTAssertEqual(snapshot.lastFlushDuration, 1.5)
    }

    func test_snapshotIsACopy() {
        let recorder = MetricsRecorder()
        let before = recorder.snapshot()

        recorder.record { $0.retries += 1 }

        XCTAssertEqual(before.retries, 0)
    }

    func test_concurrentUpdatesAreNotLost() {
        let recorder = MetricsRecorder()

        DispatchQueue.concurrentPerform(iterations: 1_000) { _ in
            recorder.record { $0.eventsStored += 1 }
        }

        XCTAssertEqual(recorder.snapshot().eventsStored, 1_000)
    }
}

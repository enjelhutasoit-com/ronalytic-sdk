//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
@testable import RonalyticFileStorage

final class SegmentMergerTests: XCTestCase {

    private func event(_ id: String, at seconds: TimeInterval) -> Event {
        Event(
            id: id,
            name: "test",
            type: .track,
            timestamp: Date(timeIntervalSince1970: seconds),
            sessionID: "sess-1",
            userID: nil,
            properties: [:]
        )
    }

    func test_emptyInput_givesEmptyOutput() {
        let merged = SegmentMerger.merge([])

        XCTAssertTrue(merged.isEmpty)
    }

    func test_interleavesByTimestamp() {
        let first = [event("a", at: 1), event("c", at: 3)]
        let second = [event("b", at: 2), event("d", at: 4)]

        let merged = SegmentMerger.merge([first, second])

        XCTAssertEqual(merged.map(\.id), ["a", "b", "c", "d"])
    }

    func test_neverReordersInsideOneList_evenIfTheClockWentBackwards() {
        let first = [event("a", at: 10), event("b", at: 5)]
        let second = [event("c", at: 7)]

        let merged = SegmentMerger.merge([first, second])

        XCTAssertEqual(merged.map(\.id), ["c", "a", "b"])
    }

    func test_equalTimestamps_preferEarlierList() {
        let first = [event("a", at: 1)]
        let second = [event("b", at: 1)]

        let merged = SegmentMerger.merge([first, second])

        XCTAssertEqual(merged.map(\.id), ["a", "b"])
    }
}

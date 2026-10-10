//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class RecordingLoggerTests: XCTestCase {
    func test_recordsEntriesInOrder() {
        let logger = RecordingLogger()

        logger.log(.error, "first")
        logger.log(.info, "second")

        XCTAssertEqual(
            logger.entries,
            [LogEntry(.error, "first"), LogEntry(.info, "second")]
        )
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class ConsoleLoggerTests: XCTestCase {
    func test_verboseLevel_printsEverything() {
        let lines = logAll(at: .verbose)

        XCTAssertEqual(lines.count, 3)
    }

    func test_infoLevel_hidesVerbose() {
        let lines = logAll(at: .info)

        XCTAssertEqual(
            lines,
            ["[Ronalytic][error] e", "[Ronalytic][info] i"]
        )
    }

    func test_errorLevel_showsOnlyErrors() {
        let lines = logAll(at: .error)

        XCTAssertEqual(lines, ["[Ronalytic][error] e"])
    }

    func test_offLevel_printsNothing() {
        let lines = logAll(at: .off)

        XCTAssertTrue(lines.isEmpty)
    }

    func test_lineHasPrefixAndLevelLabel() {
        let recorder = LineRecorder()
        let logger = ConsoleLogger(level: .verbose, output: { recorder.add($0) })

        logger.log(.verbose, "hello")

        XCTAssertEqual(
            recorder.lines,
            ["[Ronalytic][verbose] hello"]
        )
    }

    func test_levelsAreOrderedFromQuietToLoud() {
        XCTAssertTrue(LogLevel.off < .error)
        XCTAssertTrue(LogLevel.error < .info)
        XCTAssertTrue(LogLevel.info < .verbose)
    }

    // MARK: - Helper
    private func logAll(at level: LogLevel) -> [String] {
        let recorder = LineRecorder()
        let logger = ConsoleLogger(level: level, output: { recorder.add($0) })

        logger.log(.error, "e")
        logger.log(.info, "i")
        logger.log(.verbose, "v")

        return recorder.lines
    }
}

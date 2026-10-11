//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticFileStorage

final class TombstoneLogTests: XCTestCase {

    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ronalytic-tests-\(UUID().uuidString)", isDirectory: true)

    private var log: TombstoneLog {
        TombstoneLog(url: directory.appendingPathComponent("tombstones.jsonl"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_missingFile_meansNothingRemoved() throws {
        let ids = try log.readAll()

        XCTAssertTrue(ids.isEmpty)
    }

    func test_appendsAccumulate() throws {
        try log.append(["a", "b"])
        try log.append(["c"])

        let ids = try log.readAll()

        XCTAssertEqual(ids, ["a", "b", "c"])
    }

    func test_idWithNewline_survivesRoundTrip() throws {
        try log.append(["line1\nline2"])

        let ids = try log.readAll()

        XCTAssertEqual(ids, ["line1\nline2"])
    }

    func test_corruptLine_isSkipped() throws {
        try log.append(["a"])
        let handle = try FileHandle(forWritingTo: directory.appendingPathComponent("tombstones.jsonl"))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("\"unfinished".utf8))
        try handle.close()
        try log.append(["b"])

        let ids = try log.readAll()

        XCTAssertEqual(ids, ["a", "b"])
    }

    func test_replace_keepsOnlyTheGivenIDs() throws {
        try log.append(["a", "b", "c"])

        try log.replace(with: ["b"])

        XCTAssertEqual(try log.readAll(), ["b"])
    }

    func test_replace_withNoIDs_deletesTheFile() throws {
        try log.append(["a"])

        try log.replace(with: [])

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("tombstones.jsonl").path
            )
        )
    }
}

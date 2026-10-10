//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport
@testable import RonalyticFileStorage

final class JSONLinesSegmentTests: XCTestCase {

    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ronalytic-tests-\(UUID().uuidString)", isDirectory: true)

    private var url: URL { directory.appendingPathComponent("segment.jsonl") }
    private var segment: JSONLinesSegment { JSONLinesSegment(url: url) }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_append_writesOneLinePerEvent() throws {
        try segment.append([.fixture(id: "a"), .fixture(id: "b")])

        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(text.split(separator: "\n").count, 2)
        XCTAssertTrue(text.hasSuffix("\n"))
    }

    func test_append_keepsEarlierEventsAndOrder() throws {
        try segment.append([.fixture(id: "a")])
        try segment.append([.fixture(id: "b"), .fixture(id: "c")])

        let events = try segment.readAll()

        XCTAssertEqual(events.map(\.id), ["a", "b", "c"])
    }

    func test_append_createsMissingDirectories() throws {
        let nested = JSONLinesSegment(url: directory.appendingPathComponent("a/b/segment.jsonl"))

        try nested.append([.fixture(id: "a")])

        XCTAssertEqual(try nested.readAll().map(\.id), ["a"])
    }

    func test_append_emptyArray_createsNoFile() throws {
        try segment.append([])

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func test_newInstance_readsWhatAnEarlierOneWrote() throws {
        try JSONLinesSegment(url: url).append([.fixture(id: "a")])

        let events = try JSONLinesSegment(url: url).readAll()

        XCTAssertEqual(events.map(\.id), ["a"])
    }

    func test_readAll_missingFile_returnsEmpty() throws {
        let events = try segment.readAll()

        XCTAssertTrue(events.isEmpty)
    }

    func test_newlineInsideAValue_stillTakesOneLine() throws {
        try segment.append([.fixture(id: "a", name: "line1\nline2")])

        let text = try String(contentsOf: url, encoding: .utf8)
        let events = try segment.readAll()

        XCTAssertEqual(text.split(separator: "\n").count, 1)
        XCTAssertEqual(events.first?.name, "line1\nline2")
    }

    func test_roundTrip_preservesEveryField() throws {
        var event = Event.fixture(id: "a", name: "purchase")
        event.userID = "user-1"
        event.properties = ["price": 9.99, "qty": 2, "vip": true, "plan": "pro"]
        event.context = ["os.name": "iOS"]
        try segment.append([event])

        let events = try segment.readAll()

        XCTAssertEqual(events, [event])
    }

    func test_readAll_corruptLine_throwsWithLineNumber() throws {
        try segment.append([.fixture(id: "a")])
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not json\n".utf8))
        try handle.close()

        XCTAssertThrowsError(try segment.readAll()) { error in
            XCTAssertEqual(error as? JSONLinesSegment.SegmentError, .corruptLine(2))
        }
    }
}

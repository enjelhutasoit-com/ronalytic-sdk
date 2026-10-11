//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport
@testable import RonalyticFileStorage

final class AppGroupStorageTests: XCTestCase {

    private let identifier = "group.com.example.app"

    private let container = FileManager.default.temporaryDirectory
        .appendingPathComponent("ronalytic-tests-\(UUID().uuidString)", isDirectory: true)

    private var queueFolder: URL {
        container.appendingPathComponent("Ronalytic", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: container)
    }

    private func makeStorage(writerID: String) throws -> FileQueueStorage {
        try FileQueueStorage.appGroup(
            identifier: identifier,
            writerID: writerID,
            containerProvider: { [container, identifier] requested in
                requested == identifier ? container : nil
            }
        )
    }

    private func segmentFiles() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: queueFolder.path)
            .filter { $0.hasPrefix("segment-") }
            .sorted()
    }

    func test_writesInsideARonalyticFolderOfTheContainer() async throws {
        let storage = try makeStorage(writerID: "app")

        try await storage.append([.fixture(id: "a")])
        let files = try segmentFiles()

        XCTAssertEqual(files, ["segment-app.jsonl"])
    }

    func test_unavailableContainer_throwsWithTheIdentifier() {
        XCTAssertThrowsError(
            try FileQueueStorage.appGroup(
                identifier: "group.com.example.wrong",
                writerID: "app",
                containerProvider: { _ in nil }
            )
        ) { error in
            XCTAssertEqual(error as? AppGroupError, .containerUnavailable("group.com.example.wrong"))
        }
    }

    func test_appAndWidgetShareOneQueue() async throws {
        let app = try makeStorage(writerID: "app")
        let widget = try makeStorage(writerID: "widget")

        try await widget.append([.fixture(id: "from-widget")])
        let seenByApp = try await app.peek(limit: 10)

        XCTAssertEqual(seenByApp.map(\.id), ["from-widget"])
    }

    func test_differentWriterIDs_getSeparateSegmentFiles() async throws {
        let app = try makeStorage(writerID: "app")
        let widget = try makeStorage(writerID: "widget")

        try await app.append([.fixture(id: "a")])
        try await widget.append([.fixture(id: "b")])
        let files = try segmentFiles()

        XCTAssertEqual(files, ["segment-app.jsonl", "segment-widget.jsonl"])
    }

    func test_sameWriterIDAfterRelaunch_reusesTheSameFile() async throws {
        let firstLaunch = try makeStorage(writerID: "app")
        try await firstLaunch.append([.fixture(id: "a")])

        let secondLaunch = try makeStorage(writerID: "app")
        try await secondLaunch.append([.fixture(id: "b")])
        let files = try segmentFiles()
        let events = try await secondLaunch.peek(limit: 10)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(events.map(\.id), ["a", "b"])
    }
}

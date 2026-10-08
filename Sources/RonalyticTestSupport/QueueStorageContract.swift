//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore

/// Rules every QueueStorage must follow. Call each from the tests
/// of an implementation, passing a factory that makes a fresh, empty storage.
public enum QueueStorageContract {
    public typealias Factory = () -> any QueueStorage

    private static func ids(_ events: [Event]) -> [String] { events.map(\.id) }

    public static func emptyStorageHasNothing(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        let count = try await storage.count()
        let peeked = try await storage.peek(limit: 10)

        XCTAssertEqual(count, 0, file: file, line: line)
        XCTAssertTrue(peeked.isEmpty, file: file, line: line)
    }

    public static func peekReturnsAppendOrder(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        try await storage.append([.fixture(id: "a"), .fixture(id: "b")])
        try await storage.append([.fixture(id: "c")])
        let peeked = try await storage.peek(limit: 10)

        XCTAssertEqual(ids(peeked), ["a", "b", "c"], file: file, line: line)
    }

    public static func peekRespectsLimit(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])
        let peeked = try await storage.peek(limit: 2)

        XCTAssertEqual(ids(peeked), ["a", "b"], file: file, line: line)
    }

    public static func peekDoesNotRemove(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        try await storage.append([.fixture(id: "a")])
        _ = try await storage.peek(limit: 10)
        let count = try await storage.count()

        XCTAssertEqual(count, 1, file: file, line: line)
    }

    public static func removeDeletesOnlyGivenIDs(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        try await storage.append([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])
        try await storage.remove(ids: ["b"])
        let peeked = try await storage.peek(limit: 10)

        XCTAssertEqual(ids(peeked), ["a", "c"], file: file, line: line)
    }

    public static func removeUnknownIDsIsNoOp(
        _ make: Factory,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let storage = make()
        try await storage.append([.fixture(id: "a")])
        try await storage.remove(ids: ["zzz"])
        let count = try await storage.count()

        XCTAssertEqual(count, 1, file: file, line: line)
    }
}

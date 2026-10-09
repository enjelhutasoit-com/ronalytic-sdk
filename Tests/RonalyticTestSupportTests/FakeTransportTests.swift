//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport

final class FakeTransportTests: XCTestCase {
    func test_defaultsToDeliveringEverything() async throws {
        let transport = FakeTransport()

        let result = try await transport.send([.fixture(id: "a"), .fixture(id: "b")])

        XCTAssertEqual(result.delivered, ["a", "b"])
    }

    func test_recordsEveryBatchInOrder() async throws {
        let transport = FakeTransport()

        _ = try await transport.send([.fixture(id: "a")])
        _ = try await transport.send([.fixture(id: "b")])

        let batches = await transport.sentBatches
        XCTAssertEqual(batches.map { $0.map(\.id) }, [["a"], ["b"]])
    }

    func test_playsScriptedResponsesThenFallsBackToDeliverAll() async throws {
        let transport = FakeTransport(responses: [.throwError])

        await XCTAssertThrowsErrorAsync(try await transport.send([.fixture(id: "a")]))
        let second = try await transport.send([.fixture(id: "a")])

        XCTAssertEqual(second.delivered, ["a"])
    }
}

/// XCTest has no async version of XCTAssertThrowsError, so we add a tiny one.
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected an error to be thrown", file: file, line: line)
    } catch {
        // expected
    }
}

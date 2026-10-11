//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
import RonalyticCore
import RonalyticTestSupport
@testable import RonalyticHTTP

private struct Envelope: Decodable {
    let batch: [Event]
}

final class HTTPTransportTests: XCTestCase {

    private let endpoint = URL(string: "https://example.com/v1/batch")!

    override func setUp() {
        URLProtocolStub.reset()
    }

    // MARK: - Request shape

    func test_sendsPostToTheEndpointWithJSONContentType() async throws {
        let transport = makeTransport()

        _ = try await transport.send([.fixture(id: "a")])

        let request = try XCTUnwrap(URLProtocolStub.requests.first).request
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_bodyContainsEveryEventInOrder() async throws {
        let transport = makeTransport()

        _ = try await transport.send([.fixture(id: "a"), .fixture(id: "b"), .fixture(id: "c")])

        let body = try XCTUnwrap(URLProtocolStub.requests.first).body
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let envelope = try decoder.decode(Envelope.self, from: body)
        XCTAssertEqual(envelope.batch.map(\.id), ["a", "b", "c"])
    }

    func test_timestampsAreUnixMilliseconds() async throws {
        let transport = makeTransport()

        _ = try await transport.send([.fixture(id: "a")])

        let body = try XCTUnwrap(URLProtocolStub.requests.first).body
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let batch = try XCTUnwrap(json["batch"] as? [[String: Any]])
        XCTAssertEqual(batch.first?["timestamp"] as? Double, 1_000_000)
    }

    func test_sendsCustomHeaders() async throws {
        let transport = makeTransport(headers: ["X-API-Key": "secret"])

        _ = try await transport.send([.fixture(id: "a")])

        let request = try XCTUnwrap(URLProtocolStub.requests.first).request
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-API-Key"), "secret")
    }

    func test_sendsUserAgentWithSDKVersion() async throws {
        let transport = makeTransport()

        _ = try await transport.send([.fixture(id: "a")])

        let request = try XCTUnwrap(URLProtocolStub.requests.first).request
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "User-Agent"),
            "Ronalytic/\(RonalyticInfo.version)"
        )
    }

    func test_appliesTheTimeout() async throws {
        let transport = makeTransport(timeout: 12)

        _ = try await transport.send([.fixture(id: "a")])

        let request = try XCTUnwrap(URLProtocolStub.requests.first).request
        XCTAssertEqual(request.timeoutInterval, 12)
    }

    func test_emptyBatch_sendsNoRequest() async throws {
        let transport = makeTransport()

        let result = try await transport.send([])

        XCTAssertTrue(URLProtocolStub.requests.isEmpty)
        XCTAssertEqual(result, DeliveryResult(delivered: []))
    }

    // MARK: - Status mapping

    func test_successStatuses_deliverEverything() async throws {
        for status in [200, 201, 202, 204] {
            URLProtocolStub.reset(reply: .status(status))

            let result = try await makeTransport().send([.fixture(id: "a"), .fixture(id: "b")])

            XCTAssertEqual(
                result,
                DeliveryResult(delivered: ["a", "b"]),
                "status \(status)"
            )
        }
    }

    func test_temporaryFailureStatuses_areRetryable() async throws {
        for status in [408, 429, 500, 502, 503] {
            URLProtocolStub.reset(reply: .status(status))

            let result = try await makeTransport().send([.fixture(id: "a"), .fixture(id: "b")])

            XCTAssertEqual(result, DeliveryResult(delivered: [], retryable: ["a", "b"]), "status \(status)")
        }
    }

    func test_permanentClientErrors_areRejected() async throws {
        for status in [400, 404, 422] {
            URLProtocolStub.reset(reply: .status(status))

            let result = try await makeTransport().send([.fixture(id: "a"), .fixture(id: "b")])

            XCTAssertEqual(result, DeliveryResult(delivered: [], rejected: ["a", "b"]), "status \(status)")
        }
    }

    func test_networkError_isThrown() async {
        URLProtocolStub.reset(reply: .failure(URLError(.notConnectedToInternet)))
        var thrown: Error?

        do {
            _ = try await makeTransport().send([.fixture(id: "a")])
        } catch {
            thrown = error
        }

        XCTAssertEqual((thrown as? URLError)?.code, .notConnectedToInternet)
    }

    func test_outcome_unusualStatusesAreRetryable_neverDropped() {
        XCTAssertEqual(HTTPTransport.outcome(forStatus: 100), .retryable)
        XCTAssertEqual(HTTPTransport.outcome(forStatus: 304), .retryable)
        XCTAssertEqual(HTTPTransport.outcome(forStatus: 399), .retryable)
        XCTAssertEqual(HTTPTransport.outcome(forStatus: 499), .rejected)
        XCTAssertEqual(HTTPTransport.outcome(forStatus: 600), .retryable)
    }

    // MARK: - Partial failure (response body)

    func test_successBodyWithGroups_splitsTheBatchPerEvent() async throws {
        let body = #"{"delivered":["a"],"retryable":["b"],"rejected":["c"]}"#

        let result = try await send(["a", "b", "c"], body: body)

        XCTAssertEqual(result, DeliveryResult(delivered: ["a"], retryable: ["b"], rejected: ["c"]))
    }

    func test_successBodyWithoutKnownKeys_deliversEverything() async throws {
        let result = try await send(["a", "b"], body: #"{"status":"ok"}"#)

        XCTAssertEqual(result, DeliveryResult(delivered: ["a", "b"]))
    }

    func test_successBodyThatIsNotJSON_deliversEverything() async throws {
        let result = try await send(["a", "b"], body: "OK")

        XCTAssertEqual(result, DeliveryResult(delivered: ["a", "b"]))
    }

    func test_eventsMissingFromTheBody_areRetryable() async throws {
        let result = try await send(["a", "b"], body: #"{"delivered":["a"]}"#)

        XCTAssertEqual(result, DeliveryResult(delivered: ["a"], retryable: ["b"]))
    }

    func test_unknownIDsInTheBody_areIgnored() async throws {
        let body = #"{"delivered":["a","zzz"],"retryable":["b"]}"#

        let result = try await send(["a", "b"], body: body)

        XCTAssertEqual(result, DeliveryResult(delivered: ["a"], retryable: ["b"]))
    }

    func test_idInSeveralGroups_theMostCautiousGroupWins() async throws {
        let body = #"{"delivered":["a","b"],"rejected":["b","c"],"retryable":["c"]}"#

        let result = try await send(["a", "b", "c"], body: body)

        XCTAssertEqual(result, DeliveryResult(delivered: ["a"], retryable: ["c"], rejected: ["b"]))
    }

    func test_errorStatus_ignoresTheBody() async throws {
        let result = try await send(["a"], status: 503, body: #"{"delivered":["a"]}"#)

        XCTAssertEqual(result, DeliveryResult(delivered: [], retryable: ["a"]))
    }

    // MARK: - Helper

    private func makeTransport(
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) -> HTTPTransport {
        HTTPTransport(
            endpoint: endpoint,
            headers: headers,
            timeout: timeout,
            session: URLProtocolStub.makeSession()
        )
    }

    private func send(
        _ ids: [String],
        status: Int = 200,
        body: String
    ) async throws -> DeliveryResult {
        URLProtocolStub.reset(reply: .status(status, body: Data(body.utf8)))

        return try await makeTransport().send(ids.map { Event.fixture(id: $0) })
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Sends batches of events to one URL as JSON over HTTP POST.
///
/// Body: `{"batch":[...]}`. Timestamps are Unix milliseconds.
/// Status mapping: 2xx delivered, 408/429/5xx retryable, other 4xx rejected.
/// A network error is thrown, which means the whole batch failed.
///
/// Response contract (optional). On a 2xx status the server may answer with
/// `{"delivered": [ids], "retryable": [ids], "rejected": [ids]}` to report each event.
/// Events that are not listed are retried. Without such a body, 2xx means all delivered.
public struct HTTPTransport: Transport {
    public let endpoint: URL

    private let headers: [String: String]
    private let timeout: TimeInterval
    private let session: URLSession

    /// - Parameters:
    ///   - endpoint: Where batches are posted. Must be https (App Transport Security).
    ///   - headers: Extra headers, for example an API key. They override the defaults.
    ///   - timeout: Seconds before a request is given up.
    ///   - session: Replace in tests to intercept requests.
    public init(
        endpoint: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 30,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.headers = headers
        self.timeout = timeout
        self.session = session
    }

    public func send(_ batch: [Event]) async throws -> DeliveryResult {
        guard !batch.isEmpty else { return DeliveryResult(delivered: []) }

        let (data, response) = try await session.data(for: try makeRequest(batch))
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return Self.result(status: http.statusCode, body: data, batchIDs: Set(batch.map(\.id)))
    }

    enum Outcome: Equatable {
        case delivered, retryable, rejected
    }

    /// What a status code means for the events of the batch.
    /// Unknown codes are retryable: when in doubt, keep the data.
    static func outcome(forStatus status: Int) -> Outcome {
        switch status {
        case 200..<300: return .delivered
        case 408, 429: return .retryable
        case 400..<500: return .rejected
        default: return .retryable
        }
    }

    /// Combines the status code and the optional response body into one result.
    static func result(status: Int, body: Data, batchIDs ids: Set<String>) -> DeliveryResult {
        switch outcome(forStatus: status) {
        case .retryable:
            return DeliveryResult(delivered: [], retryable: ids)
        case .rejected:
            return DeliveryResult(delivered: [], rejected: ids)
        case .delivered:
            guard let report = ResponseReport(body: body) else {
                return DeliveryResult(delivered: ids)
            }
            return report.result(for: ids)
        }
    }

    private struct Body: Encodable {
        let batch: [Event]
    }

    private func makeRequest(_ batch: [Event]) throws -> URLRequest {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Ronalytic/\(RonalyticInfo.version)", forHTTPHeaderField: "User-Agent")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = try encoder.encode(Body(batch: batch))
        return request
    }
}

/// What the server says about each event of a batch. All keys are optional.
private struct ResponseReport: Decodable {
    let delivered: [String]?
    let retryable: [String]?
    let rejected: [String]?

    /// nil when the body is empty, not JSON, or has none of the known keys.
    init?(body: Data) {
        guard !body.isEmpty,
              let decoded = try? JSONDecoder().decode(ResponseReport.self, from: body),
              decoded.delivered != nil || decoded.retryable != nil || decoded.rejected != nil
        else { return nil }
        self = decoded
    }

    /// The most cautious group wins: retryable, then rejected, then delivered.
    /// Events the server did not mention are retryable. Unknown IDs are ignored.
    func result(for ids: Set<String>) -> DeliveryResult {
        let keep = Set(retryable ?? []).intersection(ids)
        let drop = Set(rejected ?? []).intersection(ids).subtracting(keep)
        let done = Set(delivered ?? []).intersection(ids).subtracting(keep).subtracting(drop)
        let unlisted = ids.subtracting(keep).subtracting(drop).subtracting(done)

        return DeliveryResult(delivered: done, retryable: keep.union(unlisted), rejected: drop)
    }
}

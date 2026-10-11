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

        let (_, response) = try await session.data(for: try makeRequest(batch))
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let ids = Set(batch.map(\.id))
        switch Self.outcome(forStatus: http.statusCode) {
        case .delivered: return DeliveryResult(delivered: ids)
        case .retryable: return DeliveryResult(delivered: [], retryable: ids)
        case .rejected: return DeliveryResult(delivered: [], rejected: ids)
        }
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

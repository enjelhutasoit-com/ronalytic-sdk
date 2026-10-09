//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Scriptable Transport for tests. Plays the given responses in order,
/// then delivers everything. Records every batch it receives.
public actor FakeTransport: Transport {
    public enum Response: Sendable {
        case deliverAll
        case throwError
        case result(DeliveryResult)
    }

    public struct Failure: Error, Sendable {}

    private var responses: [Response]
    public private(set) var sentBatches: [[Event]] = []

    public init(responses: [Response] = []) {
        self.responses = responses
    }

    public func send(_ batch: [Event]) async throws -> DeliveryResult {
        sentBatches.append(batch)
        let response = responses.isEmpty ? Response.deliverAll : responses.removeFirst()
        switch response {
        case .deliverAll:
            return DeliveryResult(delivered: Set(batch.map(\.id)))
        case .throwError:
            throw Failure()
        case .result(let result):
            return result
        }
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Outcome of sending one batch. Every event ID should land in one group.
public struct DeliveryResult: Sendable, Equatable {
    /// Accepted by the server. Remove from the queue.
    public let delivered: Set<String>
    /// Temporary problem. Keep in the queue and try again later.
    public let retryable: Set<String>
    /// Permanently refused. Remove from the queue, retrying cannot help.
    public let rejected: Set<String>
    
    init(
        delivered: Set<String>,
        retryable: Set<String> = [],
        rejected: Set<String> = []
    ) {
        self.delivered = delivered
        self.retryable = retryable
        self.rejected = rejected
    }
}

/// Sends batches to a backend.
public protocol Transport: Sendable {
    /// Throws only when the whole batch failed (for example, no network).
    func send(_ batch: [Event]) async throws -> DeliveryResult
}

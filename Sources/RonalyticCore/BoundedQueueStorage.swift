//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Wraps any QueueStorage and keeps it within `capacity` events.
/// Counts every discarded event so metrics can report it.
actor BoundedQueueStorage: QueueStorage {
    private let base: any QueueStorage
    private let capacity: Int
    private let policy: DropPolicy
    private let metrics: MetricsRecorder?
    private(set) var droppedCount = 0

    init(
        base: any QueueStorage,
        capacity: Int,
        policy: DropPolicy,
        metrics: MetricsRecorder? = nil
    ) {
        self.base = base
        self.capacity = max(capacity, 1)
        self.policy = policy
        self.metrics = metrics
    }

    func append(_ events: [Event]) async throws {
        _ = try await appendReportingStored(events)
    }

    /// Reports successful writes, excluding incoming events discarded by capacity policy.
    func appendReportingStored(_ events: [Event]) async throws -> Int {
        guard !events.isEmpty else { return 0 }
        let stored: Int
        switch policy {
        case .dropNewest:
            stored = try await appendDroppingNewest(events)
        case .dropOldest:
            stored = try await appendDroppingOldest(events)
        }
        if stored > 0 {
            metrics?.record { $0.eventsStored += stored }
        }
        return stored
    }

    func peek(limit: Int) async throws -> [Event] {
        try await base.peek(limit: limit)
    }

    func remove(ids: Set<String>) async throws {
        try await base.remove(ids: ids)
    }

    func count() async throws -> Int {
        try await base.count()
    }

    private func appendDroppingNewest(_ events: [Event]) async throws -> Int {
        let stored = try await base.count()
        let free = max(capacity - stored, 0)
        let accepted = Array(events.prefix(free))
        countDropped(events.count - accepted.count)
        guard !accepted.isEmpty else { return 0 }
        try await base.append(accepted)
        return accepted.count
    }

    private func appendDroppingOldest(_ events: [Event]) async throws -> Int {
        let incoming = Array(events.suffix(capacity))
        countDropped(events.count - incoming.count)

        let stored = try await base.count()
        let overflow = stored + incoming.count - capacity
        if overflow > 0 {
            let oldest = try await base.peek(limit: overflow)
            try await base.remove(ids: Set(oldest.map(\.id)))
            countDropped(oldest.count)
        }
        try await base.append(incoming)
        return incoming.count
    }

    private func countDropped(_ amount: Int) {
        guard amount > 0 else { return }

        droppedCount += amount
        metrics?.record { $0.eventsDroppedByQueue += amount }
    }
}

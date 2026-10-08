//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Wraps any QueueStorage and keeps it within `capacity` events.
/// Counts every discarded event so metrics can report it later.
actor BoundedQueueStorage: QueueStorage {
    private let base: any QueueStorage
    private let capacity: Int
    private let policy: DropPolicy
    private(set) var droppedCount = 0

    init(
        base: any QueueStorage,
        capacity: Int,
        policy: DropPolicy
    ) {
        self.base = base
        self.capacity = max(capacity, 1)
        self.policy = policy
    }

    func append(_ events: [Event]) async throws {
        switch policy {
        case .dropNewest:
            try await appendDroppingNewest(events)
        case .dropOldest:
            try await appendDroppingOldest(events)
        }
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

    private func appendDroppingNewest(_ events: [Event]) async throws {
        let stored = try await base.count()
        let free = max(capacity - stored, 0)
        let accepted = Array(events.prefix(free))
        droppedCount += events.count - accepted.count
        guard !accepted.isEmpty else { return }
        try await base.append(accepted)
    }

    private func appendDroppingOldest(_ events: [Event]) async throws {
        let incoming = Array(events.suffix(capacity))
        droppedCount += events.count - incoming.count

        let stored = try await base.count()
        let overflow = stored + incoming.count - capacity
        if overflow > 0 {
            let oldest = try await base.peek(limit: overflow)
            try await base.remove(ids: Set(oldest.map(\.id)))
            droppedCount += oldest.count
        }
        try await base.append(incoming)
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

import RonalyticCore

/// Non-persistent QueueStorage for tests and demos.
public actor InMemoryQueueStorage: QueueStorage {
    private var events: [Event] = []

    public init() {}

    public func append(_ newEvents: [Event]) async throws {
        events.append(contentsOf: newEvents)
    }

    public func peek(limit: Int) async throws -> [Event] {
        Array(events.prefix(max(limit, 0)))
    }

    public func remove(ids: Set<String>) async throws {
        events.removeAll { ids.contains($0.id) }
    }

    public func count() async throws -> Int {
        events.count
    }
}

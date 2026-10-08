//
// Copyright (c) 2026 Enjel Hutasoit
//

//// Ordered, durable waiting line for events.
/// Contract: append keeps order, peek never removes, remove is by event ID.
public protocol QueueStorage: Sendable {
    /// Store events after the existing ones, in the given order.
    func append(_ events: [Event]) async throws
    /// Oldest first, without removing.
    func peek(limit: Int) async throws -> [Event]
    /// Remove events with these IDs. Unknown IDs are ignored.
    func remove(ids: Set<String>) async throws
    func count() async throws -> Int
}

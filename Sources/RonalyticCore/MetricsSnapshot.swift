//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// A photo of the SDK's own counters at one moment.
/// Counters start at zero when the SDK starts and live in memory only.
public struct MetricsSnapshot: Sendable, Equatable {
    /// Events handed to the storage. Includes events the full queue then dropped.
    public internal(set) var eventsStored = 0
    /// Dropped by a plugin: filters, sampling, the consent gate.
    public internal(set) var eventsDroppedByPlugin = 0
    /// Dropped because the queue was full.
    public internal(set) var eventsDroppedByQueue = 0
    /// Dropped because the user opted out.
    public internal(set) var eventsDroppedByOptOut = 0
    /// Writes or removals that failed in the storage.
    public internal(set) var storageFailures = 0
    /// Batches the transport answered, successful or not per event.
    public internal(set) var batchesSent = 0
    /// Batches where the transport threw, for example no network.
    public internal(set) var sendFailures = 0
    /// Events confirmed by the server and removed from the queue.
    public internal(set) var eventsDelivered = 0
    /// Events refused for good by the server and removed from the queue.
    public internal(set) var eventsRejected = 0
    /// Retries that were scheduled after a failed or partial batch.
    public internal(set) var retries = 0
    /// Flushes that tried to send at least one batch.
    public internal(set) var flushes = 0
    /// Seconds the last flush took, retry waits included. nil before the first flush.
    public internal(set) var lastFlushDuration: TimeInterval?
    /// Seconds the slowest flush took.
    public internal(set) var longestFlushDuration: TimeInterval = 0

    public init() {}
}

public extension MetricsSnapshot {
    /// All counters in one readable line. Handy for `print` or a debug screen.
    var summary: String {
        let last = lastFlushDuration.map { "\($0)s" } ?? "-"
        return "stored=\(eventsStored) "
            + "dropped(plugin=\(eventsDroppedByPlugin) queue=\(eventsDroppedByQueue) "
            + "optOut=\(eventsDroppedByOptOut)) "
            + "storageFailures=\(storageFailures) "
            + "batches=\(batchesSent) sendFailures=\(sendFailures) "
            + "delivered=\(eventsDelivered) rejected=\(eventsRejected) "
            + "retries=\(retries) flushes=\(flushes) "
            + "lastFlush=\(last) longestFlush=\(longestFlushDuration)s"
    }
}

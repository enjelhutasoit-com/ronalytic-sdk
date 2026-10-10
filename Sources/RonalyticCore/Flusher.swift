//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Sends stored events in batches and removes only what was confirmed.
/// Retries with exponential backoff and jitter when a batch is not finished.
actor Flusher {
    private let storage: any QueueStorage
    private let transport: any Transport
    private let batchSize: Int
    private let backoff: BackoffPolicy
    private let clock: any SDKClock
    private let jitter: any JitterSource
    private let logger: any SDKLogger

    init(
        storage: any QueueStorage,
        transport: any Transport,
        batchSize: Int,
        backoff: BackoffPolicy = .default,
        clock: any SDKClock = SystemClock(),
        jitter: any JitterSource = SystemJitter(),
        logger: any SDKLogger = NoOpLogger()
    ) {
        self.storage = storage
        self.transport = transport
        self.batchSize = max(batchSize, 1)
        self.backoff = backoff
        self.clock = clock
        self.jitter = jitter
        self.logger = logger
    }

    /// Sends batches until the queue is empty or the retries are used up.
    /// Unsent events stay stored for a later flush.
    func flush() async {
        var failures = 0
        while let batch = try? await storage.peek(limit: batchSize), !batch.isEmpty {
            if await deliver(batch) {
                failures = 0
                continue
            }
            guard failures < backoff.maxRetries else {
                logger.log(.error, "giving up after \(failures) retries")
                return
            }

            let wait = backoff.delay(forRetry: failures, jitter: jitter.nextUnit())
            failures += 1
            logger.log(.info, "retry \(failures) in \(wait)s")
            do {
                try await clock.sleep(for: .seconds(wait))
            } catch {
                return   // cancelled
            }
        }
    }

    /// Returns true when every event of the batch is finished,
    /// so the next batch may be sent.
    private func deliver(_ batch: [Event]) async -> Bool {
        let result: DeliveryResult
        do {
            result = try await transport.send(batch)
        } catch {
            logger.log(.error, "send failed, batch of \(batch.count) kept")
            return false
        }

        let batchIDs = Set(batch.map(\.id))
        let delivered = result.delivered.intersection(batchIDs)
        let rejected = result.rejected.intersection(batchIDs)
        let finished = delivered.union(rejected)
        do {
            try await storage.remove(ids: finished)
        } catch {
            logger.log(.error, "could not remove \(finished.count) finished events from storage")
            return false
        }

        let kept = batch.count - finished.count
        logger.log(
            .verbose,
            "batch of \(batch.count): delivered \(delivered.count), rejected \(rejected.count), kept \(kept)"
        )
        return kept == 0
    }
}

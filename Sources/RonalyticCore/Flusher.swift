//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Sends stored events in batches and removes only what was confirmed.
actor Flusher {
    private let storage: any QueueStorage
    private let transport: any Transport
    private let batchSize: Int
    private let backoff: BackoffPolicy
    private let clock: any SDKClock
    private let jitter: any JitterSource

    init(
        storage: any QueueStorage,
        transport: any Transport,
        batchSize: Int,
        backoff: BackoffPolicy = .default,
        clock: any SDKClock = SystemClock(),
        jitter: any JitterSource = SystemJitter()
    ) {
        self.storage = storage
        self.transport = transport
        self.batchSize = max(batchSize, 1)
        self.backoff = backoff
        self.clock = clock
        self.jitter = jitter
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
            guard failures < backoff.maxRetries else { return }

            let wait = backoff.delay(
                forRetry: failures,
                jitter: jitter.nextUnit()
            )
            failures += 1
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
        guard let result = try? await transport.send(batch) else { return false }

        let batchIDs = Set(batch.map(\.id))
        let finished = result.delivered.union(result.rejected).intersection(batchIDs)
        do {
            try await storage.remove(ids: finished)
        } catch {
            return false
        }
        return finished.count == batch.count
    }
}

//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Sends stored events in batches and removes only what was confirmed.
actor Flusher {
    private let storage: any QueueStorage
    private let transport: any Transport
    private let batchSize: Int

    init(
        storage: any QueueStorage,
        transport: any Transport,
        batchSize: Int
    ) {
        self.storage = storage
        self.transport = transport
        self.batchSize = max(batchSize, 1)
    }

    /// Sends batches until the queue is empty or a batch is not fully finished.
    func flush() async {
        while let batch = try? await storage.peek(limit: batchSize), !batch.isEmpty {
            guard await deliver(batch) else { return }
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

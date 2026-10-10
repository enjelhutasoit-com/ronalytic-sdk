//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Everything the caller captured at the moment of the call.
struct EventDraft: Sendable {
    let id: String
    let name: String
    let type: EventType
    let timestamp: Date
    let sessionID: String
    let properties: [String: PropertyValue]
}

/// Messages sent from the public API to the processor, in call order.
enum ClientCommand: Sendable {
    case event(EventDraft)
    case identify(userID: String, draft: EventDraft)
    case flush
    /// Resumed once every earlier command is finished. Used by tests.
    case barrier(CheckedContinuation<Void, Never>)
}

/// Owns mutable state (current user) and handles commands one at a time.
actor EventProcessor {
    private let pipeline: Pipeline
    private let storage: any QueueStorage
    private let flusher: Flusher?
    private let flushThreshold: Int
    private let logger: any SDKLogger
    private var userID: String?

    init(
        pipeline: Pipeline,
        storage: any QueueStorage,
        flusher: Flusher?,
        flushThreshold: Int,
        logger: any SDKLogger = NoOpLogger()
    ) {
        self.pipeline = pipeline
        self.storage = storage
        self.flusher = flusher
        self.flushThreshold = max(flushThreshold, 1)
        self.logger = logger
    }

    func handle(_ command: ClientCommand) async {
        switch command {
        case .event(let draft):
            await store(draft)
        case .identify(let newUserID, let draft):
            userID = newUserID
            await store(draft)
        case .flush:
            await flusher?.flush()
        case .barrier(let continuation):
            continuation.resume()
        }
    }

    private func store(_ draft: EventDraft) async {
        let event = Event(
            id: draft.id,
            name: draft.name,
            type: draft.type,
            timestamp: draft.timestamp,
            sessionID: draft.sessionID,
            userID: userID,
            properties: draft.properties
        )
        guard let processed = await pipeline.run(event) else {
            logger.log(.verbose, "dropped by a plugin: \(draft.type.rawValue) \"\(draft.name)\" id=\(draft.id)")
            return
        }
        // Call sites never throw, so a storage failure is logged instead.
        // The metrics commit will also count it.
        do {
            try await storage.append([processed])
            logger.log(.verbose, "stored \(processed.type.rawValue) \"\(processed.name)\" id=\(processed.id)")
        } catch {
            logger.log(.error, "could not store \(processed.type.rawValue) \"\(processed.name)\": \(error)")
        }
        await flushIfThresholdReached()
    }

    private func flushIfThresholdReached() async {
        guard let flusher,
              let stored = try? await storage.count(),
              stored >= flushThreshold else { return }
        await flusher.flush()
    }
}

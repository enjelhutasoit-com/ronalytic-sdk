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
    private var userID: String?

    init(
        pipeline: Pipeline,
        storage: any QueueStorage,
        flusher: Flusher?
    ) {
        self.pipeline = pipeline
        self.storage = storage
        self.flusher = flusher
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
        guard let processed = await pipeline.run(event) else { return }
        // Errors are swallowed on purpose for now: call sites never throw.
        // The metrics commit will count these failures.
        try? await storage.append([processed])
    }
}

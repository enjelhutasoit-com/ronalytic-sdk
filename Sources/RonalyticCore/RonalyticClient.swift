//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// The public entry point. Every method returns immediately and never throws.
public final class RonalyticClient: Sendable {
    private let continuation: AsyncStream<ClientCommand>.Continuation
    private let clock: any SDKClock
    private let idGenerator: any IDGenerator
    private let sessionID: String

    public init(
        storage: any QueueStorage,
        plugins: [any Plugin] = [],
        clock: any SDKClock = SystemClock(),
        idGenerator: any IDGenerator = UUIDGenerator(),
        transport: (any Transport)? = nil,
        batchSize: Int = 50,
        queueCapacity: Int = 1_000,
        dropPolicy: DropPolicy = .dropOldest
    ) {
        self.clock = clock
        self.idGenerator = idGenerator
        self.sessionID = idGenerator.makeID()   // temporary, real sessions come later

        let bounded = BoundedQueueStorage(base: storage, capacity: queueCapacity, policy: dropPolicy)
        let flusher = transport.map {
            Flusher(
                storage: bounded,
                transport: $0,
                batchSize: batchSize
            )
        }
        let processor = EventProcessor(
            pipeline: Pipeline(plugins: plugins),
            storage: bounded,
            flusher: flusher
        )
        let (stream, continuation) = AsyncStream.makeStream(of: ClientCommand.self)
        self.continuation = continuation

        Task {
            for await command in stream {
                await processor.handle(command)
            }
        }
    }

    deinit {
        continuation.finish()
    }

    /// Asks the SDK to send stored events. Returns immediately.
    public func flush() {
        continuation.yield(.flush)
    }

    public func track(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        continuation.yield(.event(makeDraft(name: name, type: .track, properties: properties)))
    }

    public func screen(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        continuation.yield(.event(makeDraft(name: name, type: .screen, properties: properties)))
    }

    public func identify(
        _ userID: String,
        traits: [String: PropertyValue] = [:]
    ) {
        let draft = makeDraft(name: "identify", type: .identify, properties: traits)
        continuation.yield(.identify(userID: userID, draft: draft))
    }

    /// Suspends until everything tracked so far has been processed.
    func waitUntilIdle() async {
        await withCheckedContinuation { barrier in
            continuation.yield(.barrier(barrier))
        }
    }

    private func makeDraft(
        name: String,
        type: EventType,
        properties: [String: PropertyValue]
    ) -> EventDraft {
        EventDraft(
            id: idGenerator.makeID(),
            name: name,
            type: type,
            timestamp: clock.now(),
            sessionID: sessionID,
            properties: properties
        )
    }
}

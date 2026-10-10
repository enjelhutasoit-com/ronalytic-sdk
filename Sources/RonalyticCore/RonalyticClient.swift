//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// The public entry point. Every method returns immediately and never throws.
public final class RonalyticClient: Sendable {
    private let continuation: AsyncStream<ClientCommand>.Continuation
    private let clock: any SDKClock
    private let idGenerator: any IDGenerator
    private let sessionTracker: SessionTracker
    private let timerTask: Task<Void, Never>?
    private let optOutStore: any OptOutStore

    init(
        storage: any QueueStorage,
        plugins: [any Plugin] = [],
        clock: any SDKClock = SystemClock(),
        idGenerator: any IDGenerator = UUIDGenerator(),
        transport: (any Transport)? = nil,
        batchSize: Int = 50,
        backoff: BackoffPolicy = .default,
        flushInterval: Duration? = nil,
        queueCapacity: Int = 1_000,
        dropPolicy: DropPolicy = .dropOldest,
        sessionTimeout: TimeInterval = 1_800,
        optOutStore: any OptOutStore = InMemoryOptOutStore()
    ) {
        self.optOutStore = optOutStore
        self.clock = clock
        self.idGenerator = idGenerator
        self.sessionTracker = SessionTracker(timeout: sessionTimeout, idGenerator: idGenerator)
        let bounded = BoundedQueueStorage(base: storage, capacity: queueCapacity, policy: dropPolicy)
        let flusher = transport.map {
            Flusher(
                storage: bounded,
                transport: $0,
                batchSize: batchSize,
                backoff: backoff,
                clock: clock
            )
        }
        let processor = EventProcessor(
            pipeline: Pipeline(plugins: plugins),
            storage: bounded,
            flusher: flusher,
            flushThreshold: batchSize
        )
        let (stream, continuation) = AsyncStream.makeStream(of: ClientCommand.self)
        self.continuation = continuation

        if let flushInterval, flusher != nil {
            self.timerTask = Task {
                await FlushTimer.run(every: flushInterval, clock: clock) {
                    continuation.yield(.flush)
                }
            }
        } else {
            self.timerTask = nil
        }

        Task {
            for await command in stream {
                await processor.handle(command)
            }
        }
    }

    /// Creates a client from a configuration.
    public convenience init(config: RonalyticConfig) {
        var plugins = config.plugins
        if config.collectContext {
            // First in the list, so every later plugin (destinations) sees the context.
            let enricher = ContextEnricher(
                contextProvider: config.contextProvider,
                networkStateProvider: config.networkStateProvider
            )
            plugins.insert(enricher, at: 0)
        }
        if !config.redactionRules.isEmpty {
            // Before user plugins, so destinations only ever see cleaned data.
            plugins.insert(Redactor(rules: config.redactionRules), at: 0)
        }
        if let consent = config.consentProvider {
            // First of all, so denied events cost nothing and never reach a destination.
            let gate = ConsentGate(provider: consent, allowWhenUnknown: config.allowWhenConsentUnknown)
            plugins.insert(gate, at: 0)
        }
        self.init(
            storage: config.storage,
            plugins: plugins,
            clock: config.clock,
            idGenerator: config.idGenerator,
            transport: config.transport,
            batchSize: config.batchSize,
            backoff: config.backoff,
            flushInterval: config.flushInterval,
            queueCapacity: config.queueCapacity,
            dropPolicy: config.dropPolicy,
            sessionTimeout: config.sessionTimeout,
            optOutStore: config.optOutStore
        )
    }

    deinit {
        timerTask?.cancel()
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
        guard !optOutStore.isOptedOut() else { return }
        continuation.yield(.event(makeDraft(name: name, type: .track, properties: properties)))
    }

    public func screen(
        _ name: String,
        properties: [String: PropertyValue] = [:]
    ) {
        guard !optOutStore.isOptedOut() else { return }
        continuation.yield(.event(makeDraft(name: name, type: .screen, properties: properties)))
    }

    public func identify(
        _ userID: String,
        traits: [String: PropertyValue] = [:]
    ) {
        guard !optOutStore.isOptedOut() else { return }
        let draft = makeDraft(name: "identify", type: .identify, properties: traits)
        continuation.yield(.identify(userID: userID, draft: draft))
    }

    /// Stops collecting new events. The choice is remembered across launches.
    public func optOut() {
        optOutStore.setOptedOut(true)
    }

    /// Resumes collecting events.
    public func optIn() {
        optOutStore.setOptedOut(false)
    }

    public var isOptedOut: Bool {
        optOutStore.isOptedOut()
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
        let now = clock.now()
        let sessionID = sessionTracker.sessionID(at: now)
        return EventDraft(
            id: idGenerator.makeID(),
            name: name,
            type: type,
            timestamp: clock.now(),
            sessionID: sessionID,
            properties: properties
        )
    }
}

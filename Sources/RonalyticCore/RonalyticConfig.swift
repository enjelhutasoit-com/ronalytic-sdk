//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Every setting of the SDK in one place. Build it once at launch.
public struct RonalyticConfig: Sendable {
    /// Where events wait before they are sent. Required.
    public var storage: any QueueStorage
    /// Sends batches to a backend. Without one, events stay stored.
    public var transport: (any Transport)?
    /// Runs in order for every event: enrichers, filters, destinations.
    public var plugins: [any Plugin]
    /// Events per upload. Also the size that triggers an automatic flush.
    public var batchSize: Int
    /// How often to flush a half-full queue. nil turns the timer off.
    public var flushInterval: Duration?
    /// Waiting and retry rules after a failed upload.
    public var backoff: BackoffPolicy
    /// Maximum events kept in the queue.
    public var queueCapacity: Int
    /// What to discard when the queue is full.
    public var dropPolicy: DropPolicy
    /// Seconds of inactivity after which a new session starts.
    public var sessionTimeout: TimeInterval
    /// Adds device, app and network facts to every event. On by default.
    public var collectContext: Bool
    /// Source of device and app facts. Replace in tests.
    public var contextProvider: any ContextProvider
    /// Source of network state. Replace to report real connectivity.
    public var networkStateProvider: any NetworkStateProvider
    /// Asks the app whether tracking is allowed. nil means no consent check.
    public var consentProvider: (any ConsentProvider)?
    /// What to do while consent is unknown. false drops the events.
    public var allowWhenConsentUnknown: Bool
    /// Cleans event properties before storage. Empty by default.
    /// Recommended: [.maskEmails, .maskPhoneNumbers]
    public var redactionRules: [RedactionRule]
    /// Remembers the user's opt-out choice.
    public var optOutStore: any OptOutStore
    /// Source of time. Replace in tests.
    public var clock: any SDKClock
    /// Source of event IDs. Replace in tests.
    public var idGenerator: any IDGenerator

    public init(
        storage: any QueueStorage,
        transport: (any Transport)? = nil,
        plugins: [any Plugin] = [],
        batchSize: Int = 50,
        flushInterval: Duration? = .seconds(30),
        backoff: BackoffPolicy = .default,
        queueCapacity: Int = 1_000,
        dropPolicy: DropPolicy = .dropOldest,
        sessionTimeout: TimeInterval = 1_800,
        collectContext: Bool = true,
        contextProvider: any ContextProvider = SystemContextProvider(),
        networkStateProvider: any NetworkStateProvider = UnknownNetworkStateProvider(),
        consentProvider: (any ConsentProvider)? = nil,
        allowWhenConsentUnknown: Bool = false,
        redactionRules: [RedactionRule] = [],
        optOutStore: any OptOutStore = UserDefaultsOptOutStore(),
        clock: any SDKClock = SystemClock(),
        idGenerator: any IDGenerator = UUIDGenerator()
    ) {
        self.storage = storage
        self.transport = transport
        self.plugins = plugins
        self.batchSize = batchSize
        self.flushInterval = flushInterval
        self.backoff = backoff
        self.queueCapacity = queueCapacity
        self.dropPolicy = dropPolicy
        self.sessionTimeout = sessionTimeout
        self.collectContext = collectContext
        self.contextProvider = contextProvider
        self.networkStateProvider = networkStateProvider
        self.consentProvider = consentProvider
        self.allowWhenConsentUnknown = allowWhenConsentUnknown
        self.redactionRules = redactionRules
        self.optOutStore = optOutStore
        self.clock = clock
        self.idGenerator = idGenerator
    }
}

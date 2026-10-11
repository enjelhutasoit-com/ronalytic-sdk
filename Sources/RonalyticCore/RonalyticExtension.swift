//
// Copyright (c) 2026 Enjel Hutasoit
//

/// The entry point for app extensions and widgets.
///
/// It only writes events to the queue. It never uploads: no transport, no timer,
/// no retry. The main app reads the shared queue and sends the events.
///
/// Use the same `optOutStore` (an App Group `UserDefaults` suite) as the main app,
/// so the user's choice applies to both. Call `waitUntilStored()` before the
/// extension finishes, because the system may stop it right after.
public final class RonalyticExtension: Sendable {
    private let client: RonalyticClient

    public init(config: RonalyticConfig) {
        var config = config
        // Forced off, whatever the caller gave. An extension never uploads.
        config.transport = nil
        config.flushInterval = nil
        config.lifecycleObserver = nil
        self.client = RonalyticClient(config: config)
    }

    public func track(_ name: String, properties: [String: PropertyValue] = [:]) {
        client.track(name, properties: properties)
    }

    public func screen(_ name: String, properties: [String: PropertyValue] = [:]) {
        client.screen(name, properties: properties)
    }

    public func identify(_ userID: String, traits: [String: PropertyValue] = [:]) {
        client.identify(userID, traits: traits)
    }

    /// Suspends until every event tracked so far is written to the storage.
    /// Call it before the extension finishes.
    public func waitUntilStored() async {
        await client.waitUntilIdle()
    }
}

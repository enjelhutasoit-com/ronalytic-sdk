//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// The shared entry point: call `configure` once at launch,
/// then use `track`, `screen`, `identify` and `flush` from anywhere.
/// Calls made before `configure` are ignored. They never crash or throw.
public enum RonalyticSDK {
    private static let holder = ClientHolder()

    /// Starts the SDK. Only the first call has an effect.
    public static func configure(_ config: RonalyticConfig) {
        holder.setIfEmpty { RonalyticClient(config: config) }
    }

    public static func track(_ name: String, properties: [String: PropertyValue] = [:]) {
        holder.current?.track(name, properties: properties)
    }

    public static func screen(_ name: String, properties: [String: PropertyValue] = [:]) {
        holder.current?.screen(name, properties: properties)
    }

    public static func identify(_ userID: String, traits: [String: PropertyValue] = [:]) {
        holder.current?.identify(userID, traits: traits)
    }

    public static func flush() {
        holder.current?.flush()
    }

    public static func optOut() {
        holder.current?.optOut()
    }

    public static func optIn() {
        holder.current?.optIn()
    }

    // MARK: - Internal, for tests

    static var client: RonalyticClient? { holder.current }

    static func reset() {
        holder.clear()
    }
}

/// The only global mutable state in the SDK. Every access goes through the lock.
private final class ClientHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var client: RonalyticClient?

    var current: RonalyticClient? {
        lock.withLock { client }
    }

    /// `make` runs only when no client exists yet.
    func setIfEmpty(_ make: () -> RonalyticClient) {
        lock.withLock {
            if client == nil { client = make() }
        }
    }

    func clear() {
        lock.withLock { client = nil }
    }
}

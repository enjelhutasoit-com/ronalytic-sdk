//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation

/// Remembers whether the user turned tracking off.
public protocol OptOutStore: Sendable {
    func isOptedOut() -> Bool
    func setOptedOut(_ value: Bool)
}

/// Not persistent. For tests and apps that handle persistence themselves.
public final class InMemoryOptOutStore: OptOutStore, @unchecked Sendable {
    private let lock = NSLock()
    private var optedOut = false

    public init() {}

    public func isOptedOut() -> Bool {
        lock.withLock { optedOut }
    }

    public func setOptedOut(_ value: Bool) {
        lock.withLock { optedOut = value }
    }
}

/// Persistent. Pass a shared App Group suite to share the choice with extensions.
public struct UserDefaultsOptOutStore: OptOutStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "com.ronalytic.optedOut"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func isOptedOut() -> Bool {
        defaults.bool(forKey: key)
    }

    public func setOptedOut(_ value: Bool) {
        defaults.set(value, forKey: key)
    }
}

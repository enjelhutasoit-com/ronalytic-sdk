//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore

/// Turns app notifications into lifecycle events.
/// The notification names are injected, so tests need no UIKit.
public struct NotificationLifecycleObserver: LifecycleObserver {
    public struct Names: Sendable {
        public let background: Notification.Name
        public let foreground: Notification.Name
        public let terminate: Notification.Name

        public init(
            background: Notification.Name,
            foreground: Notification.Name,
            terminate: Notification.Name
        ) {
            self.background = background
            self.foreground = foreground
            self.terminate = terminate
        }
    }

    private let names: Names
    private let center: NotificationCenter

    public init(names: Names, center: NotificationCenter = .default) {
        self.names = names
        self.center = center
    }

    /// Each call starts listening. The listeners are removed when the stream ends.
    public func events() -> AsyncStream<LifecycleEvent> {
        AsyncStream { continuation in
            let listeners = Listeners(center: center)
            listeners.add(names.background) { continuation.yield(.didEnterBackground) }
            listeners.add(names.foreground) { continuation.yield(.willEnterForeground) }
            listeners.add(names.terminate) { continuation.yield(.willTerminate) }
            continuation.onTermination = { _ in listeners.removeAll() }
        }
    }
}

/// Holds the notification observers so they can be removed later.
private final class Listeners: @unchecked Sendable {
    private let center: NotificationCenter
    private let lock = NSLock()
    private var tokens: [any NSObjectProtocol] = []

    init(center: NotificationCenter) {
        self.center = center
    }

    func add(_ name: Notification.Name, handler: @escaping @Sendable () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: nil) { _ in handler() }
        lock.withLock { tokens.append(token) }
    }

    func removeAll() {
        let removed = lock.withLock { () -> [any NSObjectProtocol] in
            let current = tokens
            tokens = []
            return current
        }
        removed.forEach { center.removeObserver($0) }
    }
}

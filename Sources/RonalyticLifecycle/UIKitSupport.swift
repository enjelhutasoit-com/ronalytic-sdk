//
// Copyright (c) 2026 Enjel Hutasoit
//

#if canImport(UIKit)
import UIKit
import RonalyticCore

public extension NotificationLifecycleObserver.Names {
    /// The real UIKit notifications.
    static var uiKit: NotificationLifecycleObserver.Names {
        NotificationLifecycleObserver.Names(
            background: UIApplication.didEnterBackgroundNotification,
            foreground: UIApplication.willEnterForegroundNotification,
            terminate: UIApplication.willTerminateNotification
        )
    }
}

/// Asks UIApplication for background time. Not available in app extensions.
public struct UIApplicationBackgroundTaskAPI: BackgroundTaskAPI {
    public init() {}

    public func beginTask(name: String, onExpiration: @escaping @Sendable () -> Void) async -> Int? {
        await MainActor.run {
            let identifier = UIApplication.shared.beginBackgroundTask(
                withName: name,
                expirationHandler: onExpiration
            )
            return identifier == .invalid ? nil : identifier.rawValue
        }
    }

    public func endTask(_ id: Int) {
        Task { @MainActor in
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: id))
        }
    }
}
#endif

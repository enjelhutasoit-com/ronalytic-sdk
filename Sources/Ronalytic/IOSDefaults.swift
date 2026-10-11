//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import RonalyticCore
import RonalyticLifecycle

extension RonalyticConfig {
    /// Puts the given system pieces into a copy of this config.
    /// Everything else the caller set stays as it is.
    func applyingSystemIntegrations(
        lifecycleNames: NotificationLifecycleObserver.Names,
        center: NotificationCenter,
        backgroundTaskAPI: any BackgroundTaskAPI,
        networkStateProvider: any NetworkStateProvider
    ) -> RonalyticConfig {
        var config = self
        config.lifecycleObserver = NotificationLifecycleObserver(names: lifecycleNames, center: center)
        config.backgroundTaskRunner = SystemBackgroundTaskRunner(api: backgroundTaskAPI)
        config.networkStateProvider = networkStateProvider
        return config
    }
}

#if canImport(UIKit)
public extension RonalyticConfig {
    /// A config for an iOS app with everything wired up: flush when the app goes
    /// to the background (with extra background time), session handling on foreground,
    /// and real network state. Change any other setting afterwards, they are all `var`.
    ///
    /// For the main app only. App extensions must not use it, because
    /// `UIApplication.shared` is not available there.
    static func iOSDefaults(
        storage: any QueueStorage,
        transport: (any Transport)? = nil,
        plugins: [any Plugin] = []
    ) -> RonalyticConfig {
        RonalyticConfig(storage: storage, transport: transport, plugins: plugins)
            .applyingSystemIntegrations(
                lifecycleNames: .uiKit,
                center: .default,
                backgroundTaskAPI: UIApplicationBackgroundTaskAPI(),
                networkStateProvider: NetworkPathStateProvider()
            )
    }
}
#endif

//
// Copyright (c) 2026 Enjel Hutasoit
//

public enum LifecycleEvent: Sendable, Equatable {
    case didEnterBackground
    case willEnterForeground
    case willTerminate
}

/// Reports app lifecycle changes. Core stays free of UIKit:
/// the real implementation lives in the RonalyticLifecycle module.
public protocol LifecycleObserver: Sendable {
    func events() -> AsyncStream<LifecycleEvent>
}
